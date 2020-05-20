# Strongly-typed System F, at last

*Reference file:* [PolyTyped](src/PolyTyped.hs) and [SubstProperties](src/SubstProperties.hs)

Finally, we put everything together to develop a strongly-typed AST for System F. As in [Poly](src/Poly.hs), we need to use de Bruijn indices for both term and type variables.  Our general approach is to use weakly-typed ASTs for the type-level and strongly-typed ASTs at the term level. In other words, we will keep the same structure of the expression datatype that we saw in [Part II](debruijn2.md).

```haskell
     data Exp :: [Ty] -> Ty -> Type where
```

The difference is that now our types (`Ty`) can contain free type variables, which we will need to be able to substitute for.

This part is where we are really "dependently"-typed programming, and you might expect a little [Hasochism](https://dl.acm.org/doi/10.1145/2503778.2503786) to come into play.

- Good: singletons promotion means very little duplication in code.

- Not-so-good: There are a few places where the code looks a bit strange.

- Sadness: We have a proof obligation that we cannot satisfy in Haskell. What to do?

## Singleton types and promoted substitutions

This is where singletons library really comes in. If you go back to the [Subst](src/Subst.hs) and [Poly](src/Poly.hs), you'll see that some definitions are surrounded by Template Haskell brackets and calls to the `singletons` library. These definitions are processed by the library to include additional definitions that we can use for dependently-typed programming.

For example, the singletons library defines the `STy` datatype that is the
"singleton" analogue of the `Ty` datatype from [Poly](src/Poly.hs).

This means that in addition to the `Ty` datatype defined in that file:

```haskell
data Ty = IntTy | Ty :-> Ty | VarTy Idx | PolyTy Ty
```

the library also *generates* the following data type declaration (we don't have to write it)

```haskell
data STy :: Ty -> Type where
    SIntTy  :: STy IntTy
    (:%->)  :: STy a -> STy b -> STy (a :-> b)
    SVarTy  :: SIdx i -> STy (VarTy i)
    SPolyTy :: STy a -> STy (PolyTy a)
```

The `STy` type allows us to "fake" dependent types. For example, the `LamE` constructor can include a type annotation for the bound variable.

```haskell
LamE :: STy t1 -> Exp g t2 -> Exp g (t1 :-> t2)
```

More impressively, the singletons library also generates type-level analogues for the `SubstC` type class and its members using type families. There are two main differences:

  1. Type families must start with a capital letter, so in types, it is  referred to as `Subst` instead of `subst`.
  2. Type families cannot be partially applied, so if we would like to talk about `subst s` instead of `subst s ty`, we need to rely on the defunctionalization symbols generated by singletons, and use `SubstSym1 s` instead.

## Functional programming in types

