implementation module basicEditors

/********************************************************************
*                                                                   *
*   This module contains some handy basic editors manually composed *
*                                                                   *
********************************************************************/

import StdEnv
import StdGEC, StdGECExt

// the gGEC{|*|} (= gGECstar defined belwo) defined in the paper is a slightly simplified version of createNGEC 


gGECstar (string,initval,callbackfun) pst = createNGEC string Interactive True initval (\updReason -> callbackfun) pst

mkGEC :: String  t (PSt ps) -> (PSt ps) | gGEC{|*|} t & bimap{|*|} ps
mkGEC s  v env = env1                                                           
where 
	(gec,env1) = gGECstar (s,v,const id) env

selfGEC :: String (t -> t) t (PSt ps) -> (PSt ps) | gGEC{|*|} t & bimap{|*|} ps
selfGEC s f v env = env1                                                           
where 
	(gec,env1) = gGECstar (s,f v,\x -> gec.gecSetValue NoUpdate  (f x)) env

applyGECs :: (String,String) (a -> b) a (PSt ps) -> (PSt ps) | gGEC{|*|} a & gGEC{|*|} b & bimap{|*|} ps
applyGECs (sa,sb) f va env                             
   # (gec_b, env) = gGECstar (sb, f va, const id)  env 
   # (gec_a, env) = gGECstar (sa, va, set gec_b f) env     
   = env                                               

set :: (GECVALUE b (PSt ps)) (a -> b) a (PSt ps) -> (PSt ps)
set gec f va env = gec.gecSetValue NoUpdate (f va) env 
        
apply2GECs :: (String,String,String) (a -> b -> c) a b (PSt ps) -> (PSt ps)                     
                                                        | gGEC{|*|} a & gGEC{|*|} b & gGEC{|*|} c & bimap{|*|} ps                     
apply2GECs (sa,sb,sc) f va vb env = env3                                                        
where                                                                                           
   (gec_c,env1) = gGECstar (sc,f va vb,const id) env                                                   
   (gec_b,env2) = gGECstar (sb,vb,combine gec_a gec_c (flip f)) env1                                         
   (gec_a,env3) = gGECstar (sa,va,combine gec_b gec_c f) env2                                                
                                                                                                
mutualGEC :: (String,String)(a -> b) (b -> a) a
								 		  (PSt ps) -> (PSt ps) | gGEC{|*|} a & gGEC{|*|} b & bimap{|*|} ps                     
mutualGEC (sa,sb) a2b b2a va env = env2                                                      
where (gec_b,env1) = gGECstar (sa,a2b va,set gec_a b2a) env    
      (gec_a,env2) = gGECstar (sb,va,set gec_b a2b) env1   

combine :: (GECVALUE y (PSt ps)) (GECVALUE z (PSt ps))                                                    
           (x -> y -> z) x (PSt ps) -> PSt ps                                                   
combine gy gz f x env                                                                           
   # (y,env) = gy.gecGetValue env                                                               
   # env     = gz.gecSetValue NoUpdate (f x y) env                                              
   = env                                                                                        
