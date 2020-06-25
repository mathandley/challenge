{-# LANGUAGE TemplateHaskell #-}
module SubstProperties(
  axiom1, axiom2, axiom3, axiom4, axiom5, axiom6,
  axiom_map1, runTests,
  IncList, sIncList, LiftList, sLiftList
  ) where

import AssertEquality
import Imports
import Nat
import Subst

import Test.QuickCheck

-- To simplify the statement of some of the
-- properties, we define a few operations

$(singletons [d|
    -- increment all terms in a list 
    incList :: SubstDB a => [a] -> [a]
    incList = map (subst weakSub)

    -- apply the lift substitution to all terms in the list          
    liftList :: SubstDB a => Sub a -> [a] -> [a]
    liftList s = map (subst (lift s))
  |])

-- To test generic properties, we need to have an instance.
-- Therefore, we define a simple languages with variables and
-- binding to use with quickcheck.
  

data Exp :: Type where
  VarE   :: Idx  -> Exp 
  LamE   :: Exp  -> Exp          
    deriving (Eq, Show)

instance SubstDB Exp where
  var = VarE
  subst s (VarE x)  = applySub s x
  subst s (LamE e)  = LamE (subst (lift s) e)

-------------------------------------------------------------------

-- Here is a property that we need about our substitution function.
-- Why should we believe it? Note that if we are *wrong* about this property
-- we could break Haskell.
axiom1 :: forall env sub. Sing sub ->
          LiftList sub (IncList env) :~: IncList (Map (SubstSym1 sub) env)
axiom1 s = assertEquality

-- We could use quickcheck to convince us, by generating a lot of test cases.
prop_axiom1 :: Sub Exp -> [Exp] -> Bool
prop_axiom1 s g = map (subst (lift s)) (incList g) == incList (map (subst s) g)


-- With effort, we can also check this property at runtime. But this
-- also requires that we keep around more information at runtime.
check1 :: forall a (g ::[a]) (s :: Sub a).
          (TestEquality (Sing :: a -> Type), SSubstDB a, SDecide a) =>
          Sing g -> Sing s ->
           Maybe (LiftList s (IncList g) :~: 
                  IncList (Map (SubstSym1 s) g))
check1 g s = 
  testEquality
  (sLiftList s (sIncList g))
  (sIncList (sMap (SLambda @_ @_ @(SubstSym1 s) (sSubst s)) g))
  

{-

NOTE: this axiom corresponds to the following lemma from Benton et al.
which is stated as:

Lemma STyExp_cast2 : ∀ u w (sub:SubT u w) (env:Env u) (ty:Ty (S u)),
@eq Type
(Exp (STyE (STyL sub) (STyE (shSubT u) env)) (STyT (STyL sub) ty))
(Exp (STyE (shSubT _) (STyE sub env))        (STyT (STyL sub) ty)).


where
  STyE (STyL sub) (STyE (shSubT u) env)   ==   LiftList sub (IncList env)

and
  STyE (shSubT _) (STyE sub env)          ==   IncList (Map (SubstSym1 sub) env)

-}
-------------------------------------------------------------------

prop_2 :: Sub Exp -> Exp -> Exp -> Bool
prop_2 s t2 x = subst s (subst (singleSub t2) x) == subst (singleSub (subst s t2)) (subst (lift s) x)

axiom2 :: forall ty ty' sub . Sing sub ->
             Subst sub (Subst (SingleSub ty') ty) :~: Subst (SingleSub (Subst sub ty')) (Subst (Lift sub) ty)
axiom2 s = assertEquality


{-

NOTE: this axiom corresponds to the following lemma from Benton et al.
which is stated as:

Lemma STyExp_cast1 : ∀ u w (sub: SubT u w) (env: Env u)
(ty : Ty (S u)) (ty’ : Ty u),
@eq Type
(Exp (STyE sub env) (STyT [| STyT sub ty’ |] (STyT (STyL sub) ty)))
(Exp (STyE sub env) (STyT sub (STyT [| ty’ |] ty))).

STyT sub (STyT [| ty’ |] ty)  == Subst sub (Subst (SingleSub ty') ty)

STyT [| STyT sub ty’ |] (STyT (STyL sub) ty) == Subst (SingleSub (Subst sub ty')) (Subst (Lift sub) ty)



-}

-----------------------------------------------------------------------------
prop_3 :: Sub Exp -> Sub Exp -> [Exp] -> Bool
prop_3 s1 s2 g = map (subst s2) (map (subst s1) g) == map (subst (s1 <> s2)) g

axiom3 :: forall s1 s2 g. Map (SubstSym1 s2) (Map (SubstSym1 s1) g) :~: Map (SubstSym1 (s1 :<> s2)) g
axiom3 = assertEquality

prop_4 :: Exp -> Sub Exp -> [Exp] -> Bool
prop_4 t s g = map (subst (Inc (S Z) <> (t :< s))) g == map (subst s) g

axiom4 :: forall t s g. Map (SubstSym1 (Inc (S Z) :<> (t :< s))) g :~: Map (SubstSym1 s) g
axiom4 = assertEquality

prop_5 :: [Exp] -> Bool
prop_5 g = map (subst (Inc Z)) g == g

axiom5 :: forall g. Map (SubstSym1 (Inc Z)) g :~: g
axiom5 = assertEquality

-- This property is needed to implement open reduction for the polymorphic lambda terms.

axiom6 :: forall t g . Map (SubstSym1 (t ':< 'Inc 'Z)) (Map (SubstSym1 ('Inc ('S 'Z))) g) :~: g
axiom6
  | Refl <- axiom3 @(Inc (S Z)) @(t :< Inc Z) @g
  , Refl <- axiom4 @t @(Inc Z) @g
  , Refl <- axiom5 @g
  = Refl

prop_6 :: Exp -> [Exp] -> Bool
prop_6 t2 g = map (subst (t2 :< Inc Z)) (map (subst (Inc (S Z))) g) == g

-------------------------------------------------------------------

prop_assoc :: Sub Exp -> Sub Exp -> Sub Exp -> Idx -> Bool
prop_assoc s1 s2 s3 x = applySub ((s1 <> s2) <> s3) x == applySub (s1 <> (s2 <> s3)) x

prop_idL :: Sub Exp -> Idx -> Bool
prop_idL s x = applySub (s <> nilSub) x == applySub s x

prop_idR :: Sub Exp -> Idx -> Bool
prop_idR s x = applySub (nilSub <> s) x == applySub s x

prop_id :: Exp -> Bool
prop_id x = subst nilSub x == x 

prop_comp :: Sub Exp -> Sub Exp -> Exp -> Bool
prop_comp s1 s2 x = subst s2 (subst s1 x) == subst (s1 <> s2) x

-------------------------------------------------------------------
-- Properties about lists (maybe these belong in another file?)


prop_map1 :: Fun Int Int -> [Int] -> [Int] -> Bool
prop_map1 s g1 g2 = map (applyFun s) (g1 ++ g2) == map (applyFun s) g1 ++ map (applyFun s) g2

axiom_map1 :: forall s g1 g2. Map s (g1 ++ g2) :~: Map s g1 ++ Map s g2
axiom_map1 = assertEquality


prop_map2 :: [Int] -> Bool 
prop_map2 g = map id g == g

axiom_map2 :: forall g. Map IdSym0 g :~: g
axiom_map2 = assertEquality

-------------------------------------------------------------------

instance Arbitrary a => Arbitrary (Sub a) where
 arbitrary = sized gt where
   base = Inc <$> arbitrary
   gt m =
     if m <= 1 then base else
     let m' = m `div` 2 in
     frequency
     [(1, base),
      (1, (:<)    <$> arbitrary <*> gt m'), 
      (1, (:<>)   <$> gt m'     <*> gt m')]
 
 shrink (Inc n) = [Inc n' | n' <- shrink n]
 shrink (t :< s)   = s : [t' :< s' | t' <- shrink t, s' <- shrink s]
 shrink (s1 :<> s2) = s1 : s2 :
   [s1' :<> s2 | s1' <- shrink s1, s2' <- shrink s2]                       

instance Arbitrary Exp where
  arbitrary = sized gt where
   base = oneof [VarE <$> arbitrary]
   gt m =
     if m <= 1 then base else
     let m' = m `div` 2 in
     frequency
     [(1, base),
      (1, LamE    <$>  gt m')]
 
  shrink (VarE n) = [VarE n' | n' <- shrink n ]
  shrink (LamE s)   = s : [ LamE s' | s' <- shrink s]

-------------------------------------------------------------------
--

return []
runTests = $quickCheckAll
