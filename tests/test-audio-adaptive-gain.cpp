#include "../audio/dmr-normalizer/src/adaptive_gain.hpp"
#include <cmath>
#include <iostream>
static bool eq(double a,double b){return std::abs(a-b)<0.001;}
int main(){
 using namespace xlx026;
 AdaptiveGain low; for(int i=0;i<12;i++) low.observe(-38.0); if(!low.ready()||!eq(low.correction_db(),3.0)) return 1;
 AdaptiveGain high; for(int i=0;i<12;i++) high.observe(-17.0); if(!high.ready()||!eq(high.correction_db(),-3.0)) return 2;
 AdaptiveGain ideal; for(int i=0;i<12;i++) ideal.observe(-25.0); if(!ideal.ready()||!eq(ideal.correction_db(),0.0)) return 3;
 AdaptiveGainConfig big; big.hard_limit_db=9.0; AdaptiveGain capped(big); for(int i=0;i<12;i++) capped.observe(-40.0); if(!capped.ready()||!eq(capped.correction_db(),3.0)) return 4;
 AdaptiveGain silence; for(int i=0;i<30;i++) silence.observe(-90.0); if(!silence.ready()||!eq(silence.correction_db(),0.0)) return 5;
 std::cout<<"adaptive_gain_contract=PASS\n"; return 0;
}
