#include "../audio/dmr-normalizer/src/adaptive_gain.hpp"
#include <cmath>
#include <iostream>
static bool eq(double a,double b,double eps=0.002){return std::abs(a-b)<eps;}
int main(){
 using namespace xlx026;
 AdaptiveGain low; for(int i=0;i<40;i++) low.observe(-38.0); if(!low.ready()||!eq(low.correction_db(),1.0)) return 1;
 AdaptiveGain high; for(int i=0;i<40;i++) high.observe(-17.0); if(!high.ready()||!eq(high.correction_db(),-1.0)) return 2;
 AdaptiveGain ideal; for(int i=0;i<40;i++) ideal.observe(-30.0); if(!ideal.ready()||!eq(ideal.correction_db(),0.0)) return 3;
 AdaptiveGain mid; for(int i=0;i<40;i++) mid.observe(-26.60); if(!mid.ready()||!eq(mid.correction_db(),0.0)) return 8;
 AdaptiveGainConfig big; big.hard_limit_db=9.0; AdaptiveGain capped(big); for(int i=0;i<40;i++) capped.observe(-40.0); if(!capped.ready()||!eq(capped.correction_db(),1.0)) return 4;
 AdaptiveGain silence; for(int i=0;i<100;i++) silence.observe(-90.0); if(!silence.ready()||!eq(silence.correction_db(),0.0)) return 5;
 AdaptiveGain miz; for(int i=0;i<40;i++) miz.observe(-23.42); if(!miz.ready()||!eq(miz.correction_db(),-0.8225)) return 6;
 AdaptiveGain ujy; for(int i=0;i<40;i++) ujy.observe(-30.53); if(!ujy.ready()||!eq(ujy.correction_db(),0.0)) return 7;
 std::cout<<"adaptive_gain_contract=PASS\n"; return 0;
}
