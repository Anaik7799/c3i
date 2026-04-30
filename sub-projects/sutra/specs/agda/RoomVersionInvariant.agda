-- RoomVersionInvariant.agda — Room upgrade safety proofs
-- Ref: Matrix spec v1.13 client-server-api/#room-upgrades
module RoomVersionInvariant where

open import Data.Nat using (ℕ; suc; _<_; s≤s)
open import Data.Maybe using (Maybe; just; nothing; is-just)
open import Data.List using (List; []; _∷_; map)
open import Data.Product using (_×_; _,_; ∃; ∃-syntax)
open import Data.Bool using (Bool; true; false)
open import Relation.Binary.PropositionalEquality using (_≡_; refl; trans)
open import Relation.Nullary using (¬_)
open import Data.Empty using (⊥)

postulate String : Set
postulate PowerLevels : Set

record RoomState : Set where
  constructor mkRS
  field
    room-id      : String
    version      : String
    creator      : String
    power-levels : Maybe PowerLevels
    tombstone    : Maybe (String × String)  -- (new-room-id, reason)
    members      : List (String × String)   -- (mxid, membership)

IsTombstoned : RoomState → Set
IsTombstoned rs = is-just (RoomState.tombstone rs) ≡ true

record UpgradeReq : Set where
  constructor mkUpgrade
  field old-room : RoomState ; new-room-id : String ; new-version : String ; reason : String

-- New room after upgrade
newRoom : UpgradeReq → RoomState
newRoom req = mkRS
  (UpgradeReq.new-room-id req)
  (UpgradeReq.new-version req)
  (RoomState.creator (UpgradeReq.old-room req))
  (RoomState.power-levels (UpgradeReq.old-room req))
  nothing
  []

-- Old room after upgrade (tombstoned)
oldRoom : UpgradeReq → RoomState
oldRoom req = record (UpgradeReq.old-room req)
  { tombstone = just (UpgradeReq.new-room-id req , UpgradeReq.reason req) }

-- THEOREM 1: New room is NOT tombstoned
new-not-tombstoned : ∀ req → ¬ IsTombstoned (newRoom req)
new-not-tombstoned req ()

-- THEOREM 2: Old room tombstone points to new room
old-tombstone-correct : ∀ req →
  RoomState.tombstone (oldRoom req) ≡ just (UpgradeReq.new-room-id req , UpgradeReq.reason req)
old-tombstone-correct req = refl

-- THEOREM 3: Power levels copied
pl-copied : ∀ req →
  RoomState.power-levels (newRoom req) ≡ RoomState.power-levels (UpgradeReq.old-room req)
pl-copied req = refl

-- THEOREM 4: New room ID matches request
new-id-correct : ∀ req → RoomState.room-id (newRoom req) ≡ UpgradeReq.new-room-id req
new-id-correct req = refl

-- No state events on tombstoned room
data StateApp : RoomState → RoomState → Set where
  apply : ∀ {rs rs'} → ¬ IsTombstoned rs → StateApp rs rs'

-- THEOREM 5: Tombstoned room is read-only
tombstoned-readonly : ∀ rs rs' → IsTombstoned rs → ¬ StateApp rs rs'
tombstoned-readonly rs rs' ts (apply ¬ts) = ¬ts ts

-- THEOREM 6: Old room frozen after upgrade
old-frozen : ∀ req rs' → ¬ StateApp (oldRoom req) rs'
old-frozen req rs' app = tombstoned-readonly (oldRoom req) rs' refl app

-- Complete upgrade correctness
record UpgradeCorrect (req : UpgradeReq) : Set where
  constructor mkUC
  field
    p1 : ¬ IsTombstoned (newRoom req)
    p2 : RoomState.tombstone (oldRoom req) ≡ just (UpgradeReq.new-room-id req , UpgradeReq.reason req)
    p3 : RoomState.power-levels (newRoom req) ≡ RoomState.power-levels (UpgradeReq.old-room req)
    p4 : RoomState.room-id (newRoom req) ≡ UpgradeReq.new-room-id req

upgradeCorrect : ∀ req → UpgradeCorrect req
upgradeCorrect req = mkUC (λ ()) refl refl refl
