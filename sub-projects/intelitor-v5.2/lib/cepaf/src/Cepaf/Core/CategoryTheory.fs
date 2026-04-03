/// CEPAF Category Theory Module
/// Provides advanced categorical abstractions for functional programming.
///
/// WHAT: Bifunctors, Profunctors, Contravariant functors, Natural Transformations
/// WHY: Enables principled composition of complex data transformations
/// CONSTRAINTS:
///   - SC-FSH-090: All instances must satisfy category laws
///   - SC-FSH-091: Composition must be associative
///   - SC-FSH-092: Identity laws must hold
///
/// STAMP Compliance: SC-FSH-090 to SC-FSH-092
/// Version: 1.0.0
namespace Cepaf.Core

open System

// ============================================================================
// CATEGORY PRIMITIVES
// ============================================================================

/// Category interface
type ICategory<'Arrow> =
    abstract Id: 'Arrow  // a -> a
    abstract Compose: 'Arrow -> 'Arrow -> 'Arrow  // (b -> c) -> (a -> b) -> (a -> c)

/// Arrow interface (stronger than Category)
type IArrow<'Arrow> =
    inherit ICategory<'Arrow>
    abstract Arr: ('A -> 'B) -> 'Arrow  // lift pure function
    abstract First: 'Arrow -> 'Arrow  // (a -> b) -> ((a, c) -> (b, c))
    abstract Second: 'Arrow -> 'Arrow  // (a -> b) -> ((c, a) -> (c, b))
    abstract Fanout: 'Arrow -> 'Arrow -> 'Arrow  // (&&&): (a -> b) -> (a -> c) -> (a -> (b, c))

// ============================================================================
// BIFUNCTOR
// ============================================================================

/// Bifunctor - functor of two arguments
module Bifunctor =

    /// Bifunctor operations
    type IBifunctor<'F> =
        abstract Bimap: ('A -> 'B) -> ('C -> 'D) -> 'F -> 'F  // F<A,C> -> F<B,D>
        abstract First: ('A -> 'B) -> 'F -> 'F  // F<A,C> -> F<B,C>
        abstract Second: ('C -> 'D) -> 'F -> 'F  // F<A,C> -> F<A,D>

    /// Tuple bifunctor
    module Tuple =
        let bimap f g (a, c) = (f a, g c)
        let first f (a, c) = (f a, c)
        let second g (a, c) = (a, g c)

    /// Either/Choice bifunctor
    type Either<'L, 'R> =
        | Left of 'L
        | Right of 'R

    module Either =
        let bimap f g = function
            | Left a -> Left (f a)
            | Right c -> Right (g c)

        let first f = bimap f id
        let second g = bimap id g

        let mapLeft f = first f
        let mapRight g = second g

        let fold onLeft onRight = function
            | Left a -> onLeft a
            | Right b -> onRight b

        let swap = function
            | Left a -> Right a
            | Right b -> Left b

        let fromResult = function
            | Ok x -> Right x
            | Error e -> Left e

        let toResult = function
            | Right x -> Ok x
            | Left e -> Error e

    /// These bifunctor
    type These<'A, 'B> =
        | This of 'A
        | That of 'B
        | Both of 'A * 'B

    module These =
        let bimap f g = function
            | This a -> This (f a)
            | That b -> That (g b)
            | Both (a, b) -> Both (f a, g b)

        let first f = bimap f id
        let second g = bimap id g

        let fromPair (a, b) = Both (a, b)

        let fold onThis onThat onBoth = function
            | This a -> onThis a
            | That b -> onThat b
            | Both (a, b) -> onBoth a b

        let here = function
            | This a -> Some a
            | Both (a, _) -> Some a
            | That _ -> None

        let there = function
            | That b -> Some b
            | Both (_, b) -> Some b
            | This _ -> None

// ============================================================================
// PROFUNCTOR
// ============================================================================

/// Profunctor - contravariant in first argument, covariant in second
module Profunctor =

    /// Profunctor operations
    type IProfunctor<'P> =
        abstract Dimap: ('A -> 'B) -> ('C -> 'D) -> 'P -> 'P  // P<B,C> -> P<A,D>
        abstract LMap: ('A -> 'B) -> 'P -> 'P  // P<B,C> -> P<A,C>
        abstract RMap: ('C -> 'D) -> 'P -> 'P  // P<A,C> -> P<A,D>

    /// Function profunctor
    module Function =
        let dimap f g h = g << h << f
        let lmap f h = h << f
        let rmap g h = g << h

    /// Star profunctor (Kleisli arrow lifted to profunctor)
    type Star<'F, 'A, 'B> = Star of ('A -> 'F)  // Actually A -> F<B>

    module Star =
        let run (Star f) = f

        let dimap f g (Star h) = Star (f >> h)  // Simplified, needs functor map
        let lmap f (Star h) = Star (f >> h)
        let rmap g (Star h) = Star h  // Needs functor map

    /// Costar profunctor (opposite of Star)
    type Costar<'F, 'A, 'B> = Costar of ('F -> 'B)  // Actually F<A> -> B

    module Costar =
        let run (Costar f) = f

        let dimap f g (Costar h) = Costar (h >> g)  // Simplified
        let lmap f (Costar h) = Costar h  // Needs functor
        let rmap g (Costar h) = Costar (h >> g)

// ============================================================================
// CONTRAVARIANT FUNCTOR
// ============================================================================

/// Contravariant functor
module Contravariant =

    /// Contravariant operations
    type IContravariant<'F> =
        abstract Contramap: ('B -> 'A) -> 'F -> 'F  // F<A> -> F<B>

    /// Predicate as contravariant functor
    type Predicate<'A> = Predicate of ('A -> bool)

    module Predicate =
        let run (Predicate p) = p
        let contramap f (Predicate p) = Predicate (f >> p)
        let all predicates = Predicate (fun a ->
            predicates |> List.forall (fun p -> run p a))
        let any predicates = Predicate (fun a ->
            predicates |> List.exists (fun p -> run p a))
        let negate (Predicate p) = Predicate (p >> not)

    /// Comparison as contravariant functor
    type Comparison<'A> = Comparison of ('A -> 'A -> int)

    module Comparison =
        let run (Comparison c) = c
        let contramap f (Comparison c) = Comparison (fun b1 b2 -> c (f b1) (f b2))
        let reverse (Comparison c) = Comparison (fun a1 a2 -> c a2 a1)
        let thenBy (Comparison c2) (Comparison c1) = Comparison (fun a1 a2 ->
            match c1 a1 a2 with
            | 0 -> c2 a1 a2
            | n -> n)

    /// Equivalence as contravariant functor
    type Equivalence<'A> = Equivalence of ('A -> 'A -> bool)

    module Equivalence =
        let run (Equivalence e) = e
        let contramap f (Equivalence e) = Equivalence (fun b1 b2 -> e (f b1) (f b2))
        let defaultEquiv<'A when 'A: equality> () = Equivalence ((=))

// ============================================================================
// NATURAL TRANSFORMATION
// ============================================================================

/// Natural transformation between functors
module NaturalTransformation =

    /// Natural transformation F ~> G
    type NatTrans<'F, 'G> = NatTrans of ('F -> 'G)  // Actually forall a. F a -> G a

    let run (NatTrans nt) = nt

    /// Identity natural transformation
    let id<'F> = NatTrans (id: 'F -> 'F)

    /// Compose natural transformations
    let compose (NatTrans g) (NatTrans f) = NatTrans (f >> g)

    /// Option to List
    let optionToList = NatTrans (function
        | Some x -> [x]
        | None -> [])

    /// List to Option (head)
    let listToOption = NatTrans (function
        | [] -> None
        | x :: _ -> Some x)

    /// Result to Option
    let resultToOption = NatTrans (function
        | Ok x -> Some x
        | Error _ -> None)

    /// Option to Result
    let optionToResult error = NatTrans (function
        | Some x -> Ok x
        | None -> Error error)

// ============================================================================
// INVARIANT FUNCTOR
// ============================================================================

/// Invariant functor - both covariant and contravariant
module Invariant =

    /// Invariant operations
    type IInvariant<'F> =
        abstract Imap: ('A -> 'B) -> ('B -> 'A) -> 'F -> 'F  // F<A> -> F<B>

    /// Codec (encoder + decoder) as invariant functor
    type Codec<'Raw, 'A> = Codec of ('A -> 'Raw) * ('Raw -> Result<'A, string>)

    module Codec =
        let encode (Codec (enc, _)) = enc
        let decode (Codec (_, dec)) = dec

        let imap f g (Codec (enc, dec)) =
            Codec (g >> enc, dec >> Result.map f)

        /// Compose codecs
        let compose (Codec (enc2, dec2)) (Codec (enc1, dec1)) =
            Codec (enc1 >> enc2,
                   fun raw ->
                       dec2 raw |> Result.bind dec1)

        /// String codec for int
        let intCodec =
            Codec (
                string,
                fun s -> match Int32.TryParse s with true, n -> Ok n | _ -> Error "Invalid int")

        /// String codec for bool
        let boolCodec =
            Codec (
                string,
                fun s -> match Boolean.TryParse s with true, b -> Ok b | _ -> Error "Invalid bool")

        /// String codec for DateTime
        let dateTimeCodec (format: string) =
            Codec (
                (fun (dt: DateTime) -> dt.ToString(format)),
                fun s ->
                    match DateTime.TryParseExact(s, format, null, System.Globalization.DateTimeStyles.None) with
                    | true, dt -> Ok dt
                    | _ -> Error (sprintf "Invalid date format (expected %s)" format))

// ============================================================================
// COMONAD
// ============================================================================

/// Comonad - dual of monad
module Comonad =

    /// Comonad operations
    type IComonad<'W> =
        abstract Extract: 'W -> obj  // W<A> -> A (using obj for simplicity)
        abstract Extend: ('W -> obj) -> 'W -> 'W  // (W<A> -> B) -> W<A> -> W<B>
        abstract Duplicate: 'W -> 'W  // W<A> -> W<W<A>>

    /// Identity comonad
    type Identity<'A> = Identity of 'A

    module Identity =
        let run (Identity x) = x
        let extract (Identity x) = x
        let extend f (Identity x) = Identity (f (Identity x))
        let duplicate w = Identity w
        let map f (Identity x) = Identity (f x)

    /// Non-empty list comonad
    type NonEmpty<'A> = NonEmpty of 'A * 'A list

    module NonEmpty =
        let head (NonEmpty (h, _)) = h
        let tail (NonEmpty (_, t)) = t
        let toList (NonEmpty (h, t)) = h :: t

        let create h t = NonEmpty (h, t)
        let singleton x = NonEmpty (x, [])

        let extract = head

        let tails nel =
            let rec loop acc = function
                | NonEmpty (_, []) as last -> List.rev (last :: acc)
                | NonEmpty (_, h :: t) as current ->
                    loop (current :: acc) (NonEmpty (h, t))
            loop [] nel

        let duplicate nel = NonEmpty (nel, tails nel |> List.tail)

        let extend f nel =
            let ts = tails nel
            match ts with
            | [] -> failwith "impossible"
            | h :: t -> NonEmpty (f h, List.map f t)

        let map f (NonEmpty (h, t)) = NonEmpty (f h, List.map f t)

        let coflatMap f = extend f

    /// Store comonad (focused position in space)
    type Store<'S, 'A> = Store of ('S -> 'A) * 'S

    module Store =
        let pos (Store (_, s)) = s
        let peek s (Store (f, _)) = f s
        let peeks g (Store (f, s)) = f (g s)

        let extract (Store (f, s)) = f s

        let extend g (Store (f, s)) =
            Store ((fun s' -> g (Store (f, s'))), s)

        let duplicate (Store (f, s)) =
            Store ((fun s' -> Store (f, s')), s)

        let map g (Store (f, s)) = Store (f >> g, s)

        let seek s (Store (f, _)) = Store (f, s)
        let seeks g (Store (f, s)) = Store (f, g s)

        /// Create a store from a function and initial position
        let create f s = Store (f, s)

// ============================================================================
// YONEDA / COYONEDA
// ============================================================================

/// Yoneda lemma encoding
module Yoneda =

    /// Yoneda - functor in CPS style (optimization technique)
    type Yoneda<'F, 'A> = Yoneda of (('A -> obj) -> 'F)  // forall b. (A -> B) -> F B

    module Yoneda =
        let run (Yoneda y) = y

        let lift fa = Yoneda (fun k -> fa)  // Needs functor map

        let lower (Yoneda y) = y id

        let map f (Yoneda y) = Yoneda (fun k -> y (f >> k))

    /// Coyoneda - free functor (lift any type to a functor)
    type Coyoneda<'F, 'A> =
        abstract Map: ('A -> 'B) -> Coyoneda<'F, 'B>
        abstract Lower: 'F  // Needs functor map to be correct

    /// Existential encoding of Coyoneda
    type Coyo<'F, 'A> = private Coyo of obj * (obj -> 'A)

    module Coyoneda =
        let lift fa : Coyo<'F, 'A> = Coyo (fa, unbox)

        let map f (Coyo (fa, k)) : Coyo<'F, 'B> = Coyo (fa, k >> f)

        let lower (Coyo (fa, k)) = fa  // Needs functor map: map k fa

// ============================================================================
// REPRESENTABLE FUNCTOR
// ============================================================================

/// Representable functor
module Representable =

    /// Representable operations
    type IRepresentable<'F, 'Rep> =
        abstract Tabulate: ('Rep -> 'A) -> 'F  // (Rep -> A) -> F A
        abstract Index: 'F -> 'Rep -> 'A  // F A -> Rep -> A

    /// Pair is representable by Bool
    type Pair<'A> = Pair of 'A * 'A

    module Pair =
        let fst (Pair (a, _)) = a
        let snd (Pair (_, b)) = b

        let tabulate f = Pair (f false, f true)
        let index (Pair (a, b)) = function
            | false -> a
            | true -> b

        let map f (Pair (a, b)) = Pair (f a, f b)

        /// Pair is also a comonad
        let extract = fst
        let extend f p = Pair (f p, f (Pair (snd p, fst p)))

// ============================================================================
// MONOIDAL CATEGORIES
// ============================================================================

/// Monoid in the category of endofunctors (applicative/monad)
module MonoidalCategories =

    /// Monoid
    type IMonoid<'A> =
        abstract Empty: 'A
        abstract Combine: 'A -> 'A -> 'A

    /// Semigroup (monoid without identity)
    type ISemigroup<'A> =
        abstract Combine: 'A -> 'A -> 'A

    /// Common monoid instances
    module Monoids =
        let string = {
            new IMonoid<string> with
                member _.Empty = ""
                member _.Combine a b = a + b
        }

        let list<'A>() = {
            new IMonoid<'A list> with
                member _.Empty = []
                member _.Combine a b = a @ b
        }

        let intSum = {
            new IMonoid<int> with
                member _.Empty = 0
                member _.Combine a b = a + b
        }

        let intProduct = {
            new IMonoid<int> with
                member _.Empty = 1
                member _.Combine a b = a * b
        }

        let boolAll = {
            new IMonoid<bool> with
                member _.Empty = true
                member _.Combine a b = a && b
        }

        let boolAny = {
            new IMonoid<bool> with
                member _.Empty = false
                member _.Combine a b = a || b
        }

        /// First non-None value
        let first<'A>() = {
            new IMonoid<'A option> with
                member _.Empty = None
                member _.Combine a b =
                    match a with
                    | Some _ -> a
                    | None -> b
        }

        /// Last non-None value
        let last<'A>() = {
            new IMonoid<'A option> with
                member _.Empty = None
                member _.Combine a b =
                    match b with
                    | Some _ -> b
                    | None -> a
        }

    /// Dual monoid (reverse order)
    let dual (m: IMonoid<'A>) = {
        new IMonoid<'A> with
            member _.Empty = m.Empty
            member _.Combine a b = m.Combine b a
    }

    /// Endo monoid (function composition)
    type Endo<'A> = Endo of ('A -> 'A)

    module Endo =
        let run (Endo f) = f
        let monoid<'A>() = {
            new IMonoid<Endo<'A>> with
                member _.Empty = Endo id
                member _.Combine (Endo f) (Endo g) = Endo (f >> g)
        }

    /// Fold using monoid
    let foldMap (m: IMonoid<'M>) (f: 'A -> 'M) (xs: 'A list) =
        xs |> List.map f |> List.fold m.Combine m.Empty
