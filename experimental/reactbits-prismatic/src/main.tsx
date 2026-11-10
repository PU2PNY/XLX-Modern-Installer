import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import './index.css';

const target = document.getElementById('root');
if (target) createRoot(target).render(<React.StrictMode><App /></React.StrictMode>);
