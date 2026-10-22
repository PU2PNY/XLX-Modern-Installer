"""Synthetic registry fixtures only; never run against a production database."""
import contextlib
import functools
import io
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest.mock import patch

import radioid_delta as delta
import reconcile_radioid as worker

ROW = {'id': 9990001, 'radio_id': 9990001, 'callsign': 'ZZ1AAA',
       'fname': 'Fixture', 'surname': '', 'city': 'Test City',
       'state': 'Minas Gerais', 'country': 'Brazil'}
XML = '<STATION><Callsign>ZZ1AAA</Callsign><Via node>TEST B</Via node></STATION>'


def response(rows):
    return io.StringIO(json.dumps({'results': rows}))


class RegistryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.csv = self.root/'users.csv'
        self.csv.write_text('ID,Callsign,Fname,Surname,City,State,Country\n9990002,ZZ1BBB,Other,,Elsewhere,SP,Brazil\n')
        self.db = self.root/'users.db'
        with sqlite3.connect(self.db) as db:
            db.execute('CREATE TABLE users(callsign TEXT PRIMARY KEY,name TEXT,city_state TEXT)')
            db.execute("INSERT INTO users VALUES ('ZZ1BBB','Other','Elsewhere, SP')")
        self.save = functools.partial(delta.save_verified, csv_path=self.csv, db_path=self.db,
                                      lock_path=self.root/'lock', backup_dir=self.root/'backups')
        self.patches = [patch.object(worker, 'DB', str(self.db)),
                        patch.object(worker, 'STATE', str(self.root/'state.json')),
                        patch.object(worker, 'save_verified', self.save),
                        patch.object(worker, 'store_profile', lambda row: None)]
        for p in self.patches:
            p.start()

    def tearDown(self):
        for p in reversed(self.patches):
            p.stop()
        self.temp.cleanup()

    def stored(self):
        with sqlite3.connect(self.db) as db:
            return db.execute("SELECT name,city_state FROM users WHERE callsign='ZZ1AAA'").fetchone()

    def test_single_save_preserves_other_rows_and_is_idempotent(self):
        before = self.csv.read_text()
        self.save(ROW)
        self.assertEqual(self.stored(), ('Fixture', 'Test City, MG'))
        self.assertTrue(self.csv.read_text().startswith(before))
        self.save(ROW)
        self.assertEqual(self.csv.read_text().count('9990001,'), 1)
        with sqlite3.connect(self.db) as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM users').fetchone()[0], 2)
            self.assertEqual(db.execute("SELECT name,city_state FROM users WHERE callsign='ZZ1BBB'").fetchone(), ('Other', 'Elsewhere, SP'))

    def test_repair_csv_present_sql_missing(self):
        with self.csv.open('a') as f:
            f.write('9990001,ZZ1AAA,Fixture,,Test City,Minas Gerais,Brazil\n')
        self.save(ROW)
        self.assertEqual(self.stored(), ('Fixture', 'Test City, MG'))
        self.assertEqual(self.csv.read_text().count('9990001,'), 1)

    def test_conflicting_identity_is_not_overwritten(self):
        original = self.csv.read_bytes(), self.db.read_bytes()
        with self.assertRaises(ValueError):
            self.save(ROW | {'id': 9990002, 'radio_id': 9990002})
        self.assertEqual((self.csv.read_bytes(), self.db.read_bytes()), original)

    def test_failed_db_publication_restores_both_files(self):
        original = self.csv.read_bytes(), self.db.read_bytes()
        replace = delta.os.replace
        def fail_once(src, dst):
            if str(Path(src).name).startswith('.radioid-db-'):
                raise OSError('synthetic publication failure')
            return replace(src, dst)
        with patch.object(delta.os, 'replace', fail_once), self.assertRaises(OSError):
            self.save(ROW)
        self.assertEqual((self.csv.read_bytes(), self.db.read_bytes()), original)

    def test_disconnected_station_is_observed(self):
        self.assertEqual(worker.observed_calls(XML), ['ZZ1AAA'])

    def test_failed_attempt_retries_after_one_minute_not_one_day(self):
        state = {'new_call:ZZ1AAA': 9900}  # Legacy marker must not suppress retry.
        with patch.object(worker.urllib.request, 'urlopen', side_effect=TimeoutError):
            self.assertEqual(worker.reconcile_new_calls(XML, 10000, state), 'lookup_failed_ZZ1AAA')
        self.assertEqual(state['lookup_results']['ZZ1AAA']['next_retry'], 10060)
        with patch.object(worker.urllib.request, 'urlopen', return_value=response([ROW])) as fetch:
            self.assertEqual(worker.reconcile_new_calls(XML, 10030, state), None)
            self.assertEqual(fetch.call_count, 0)
            self.assertEqual(worker.reconcile_new_calls(XML, 10061, state), 'added_ZZ1AAA')
        self.assertIsNotNone(self.stored())

    def test_missing_official_identity_is_not_fabricated(self):
        state = {}
        with patch.object(worker.urllib.request, 'urlopen', return_value=response([])):
            self.assertEqual(worker.reconcile_new_calls(XML, 10000, state), 'not_found_ZZ1AAA')
        self.assertIsNone(self.stored())
        self.assertEqual(state['lookup_results']['ZZ1AAA']['next_retry'], 13600)

    def test_ambiguous_or_incomplete_official_rows_not_written(self):
        for rows in ([ROW, ROW], [ROW | {'city': ''}], [ROW | {'callsign': 'ZZ1OTHER'}]):
            with patch.object(worker.urllib.request, 'urlopen', return_value=response(rows)):
                worker.reconcile_new_calls(XML, 10000, {})
            self.assertIsNone(self.stored())

    def test_profile_failure_retries_even_after_sql_insert(self):
        state = {}
        with patch.object(worker.urllib.request, 'urlopen', return_value=response([ROW])), patch.object(worker, 'store_profile', side_effect=OSError):
            self.assertEqual(worker.reconcile_new_calls(XML, 10000, state), 'profile_failed_ZZ1AAA')
        self.assertIsNotNone(self.stored())
        with patch.object(worker.urllib.request, 'urlopen', return_value=response([ROW])):
            self.assertEqual(worker.reconcile_new_calls(XML, 10061, state), 'added_ZZ1AAA')

    def test_complete_local_user_never_triggers_external_lookup(self):
        self.save(ROW)
        with patch.object(worker.urllib.request, 'urlopen') as fetch:
            self.assertIsNone(worker.reconcile_new_calls(XML, 10000, {}))
            fetch.assert_not_called()

    def test_global_rate_limit(self):
        with patch.object(worker.urllib.request, 'urlopen') as fetch:
            self.assertEqual(worker.reconcile_new_calls(XML, 10000, {'_new_calls_last': 9990}), 'rate_limited')
            fetch.assert_not_called()


if __name__ == '__main__':
    unittest.main()
