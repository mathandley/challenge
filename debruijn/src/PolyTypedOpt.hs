-- | Optimized version of Strongly-typed System F
module PolyTypedOpt where

import Imports
import qualified Subst as W
import SubstProperties 
import qualified SubstTypedOpt as S

-- We import the definition of types from the "untyped" AST so that we can
-- later write a type checker that shares these types. (See TypeCheck.hs).
import Poly (Ty(..),STy(..))

data Exp :: [Ty] -> Ty -> Type where

  IntE   :: Int
         -> Exp g IntTy

  VarE   :: S.Idx g t
         -> Exp g t

  LamE   :: Π t1                  -- type of binder
         -> S.Bind Exp t1 g t2    -- body of abstraction
         -> Exp g (t1 :-> t2)

  AppE   :: Exp g (t1 :-> t2)     -- function
         -> Exp g t1              -- argument
         -> Exp g t2

  TyLam  :: Exp (IncList g) t     -- bind a type variable
         -> Exp g (PolyTy t)

  TyApp  :: Exp g (PolyTy t1)     -- type function
         -> Π t2               -- type argument
         -> Exp g (W.Subst (W.SingleSub t2) t1)

instance S.SubstDB Exp where
   var = VarE

   subst s (IntE x)     = IntE x
   subst s (VarE x)     = S.applySub s x
   subst s (LamE ty e)  = LamE ty (S.substBind s e)
   subst s (AppE e1 e2) = AppE (S.subst s e1) (S.subst s e2)
   subst s (TyLam e)    = TyLam (S.subst (incTy W.sIncSub s) e)
   subst s (TyApp e t)  = TyApp (S.subst s e) t

substTy :: forall g s ty.
   Π (s :: W.Sub Ty) -> Exp g ty -> Exp (Map (W.SubstSym1 s) g) (W.Subst s ty)
substTy s (IntE x)     = IntE x
substTy s (VarE n)     = VarE $ S.mapIdx @(W.SubstSym1 s)  n
substTy s (LamE t e)   = LamE (W.sSubst s t) (S.bind (substTy s (S.unbind e)))
substTy s (AppE e1 e2) = AppE (substTy s e1) (substTy s e2)
substTy s (TyLam (e :: Exp (IncList g) t))    
    | Refl <- axiom1 @g s = TyLam (substTy (W.sLift s) e)
substTy s (TyApp (e :: Exp g (PolyTy t1)) (t :: STy t2))  
    | Refl <- axiom2 @t1 @t2 s
                       = TyApp (substTy s e) (W.sSubst s t)

incTy :: forall s g g'. Π s -> S.Sub Exp g g' -> S.Sub Exp (Map (W.SubstSym1 s) g) (Map (W.SubstSym1 s) g')
incTy s (S.Inc (x :: S.IncBy g1)) 
  | Refl <- axiom_map1 @(W.SubstSym1 s) @g1 @g = S.Inc (S.mapInc @(W.SubstSym1 s)  x) 
incTy s (e S.:< s1)   = substTy s e S.:< incTy s s1
incTy s (s1 S.:<> s2) = incTy s s1 S.:<> incTy s s2


-------------------------------------------------------------------

-- | Small-step evaluation of closed terms
step :: Exp '[] t -> Maybe (Exp '[] t)
step (IntE x)     = Nothing
step (VarE n)     = case n of {}  
step (LamE t e)   = Nothing
step (AppE e1 e2) = Just $ stepApp e1 e2
step (TyLam e)    = Nothing
step (TyApp e t)  = Just $ stepTyApp e t

-- | Helper function for the AppE case. This function proves that we will
-- *always* take a step if a closed term is an application expression.
stepApp :: Exp '[] (t1 :-> t2) -> Exp '[] t1  -> Exp '[] t2
--stepApp (IntE x)       e2 = error "Type error"
stepApp (VarE n)       e2 = case n of {}
stepApp (LamE t e1)    e2 = S.instantiate e1 e2
stepApp (AppE e1' e2') e2 = AppE (stepApp e1' e2') e2
--stepApp (TyLam e)      e2 = error "Type error"
stepApp (TyApp e1 t1)  e2 = AppE (stepTyApp e1 t1) e2

-- | Helper function for the TyApp case. This function proves that we will
-- *always* take a step if a closed term is a type application expression.
stepTyApp :: Exp '[] (PolyTy t1) -> Π t -> Exp '[] (W.Subst (W.SingleSub t) t1)
--stepTyApp (IntE x)       e2 = error "Type error"
stepTyApp (VarE n)       t1 = case n of {}
--stepTyApp (LamE t e1)    t1 = error "Type error"
stepTyApp (AppE e1' e2') t1 = TyApp (stepApp e1' e2') t1
stepTyApp (TyLam e1)     t1 = substTy (W.sSingleSub t1) e1
stepTyApp (TyApp e1 t2)  t1 = TyApp (stepTyApp e1 t2) t1

-- | open reduction
reduce :: forall g t. Exp g t -> Exp g t
reduce (IntE x)   = IntE x
reduce (VarE n)   = VarE n
reduce (LamE t e) = LamE t (S.bind (reduce (S.unbind e)))
reduce (AppE (LamE t e1) e2) = S.subst (S.single (reduce e2)) (reduce (S.unbind e1))
--reduce (AppE (IntE x)     e2) = error "Type error"
--reduce (AppE (TyLam e1)   e2) = error "Type error"
reduce (AppE e1 e2)          = AppE (reduce e1) (reduce e2)
reduce (TyLam e)             = TyLam (reduce e)
reduce (TyApp (TyLam e) (t1 :: STy t1))
      | Refl <- axiom6 @t1 @g
      = substTy (W.sSingleSub t1) (reduce e)
--reduce (TyApp (IntE x)     t) = error "Type error"
--reduce (TyApp (LamE t1 e2) t) = error "Type error"    
reduce (TyApp e t)           = TyApp (reduce e) t
