/-!
# Hypercode cascade resolution — Lean 4 oracle

An executable model of the Hypercode cascade (the same rules implemented in
`Sources/Hypercode/HCS/`). It serves as a machine-checked oracle:

* the service example resolves to exactly the values the Swift implementation
  produces (checked by `native_decide`), and
* the precedence ordering facts that determinism rests on are checked in the
  kernel (`rfl`), together with a totality theorem for the cascade.

Lean enforces that every definition below is total, so the model cannot be
ill-defined.
-/

namespace Hypercode

/-- A small helper: lexicographic combination of two orderings. -/
def lexThen : Ordering → Ordering → Ordering
  | .eq, o => o
  | o, _   => o

/-- `concatMap` (self-contained, no Batteries dependency). -/
def concatMap (f : α → List β) : List α → List β
  | []      => []
  | a :: as => f a ++ concatMap f as

/-- Remove duplicates, keeping first occurrences. -/
partial def nub [BEq α] : List α → List α
  | []      => []
  | a :: as => a :: nub (as.filter (· != a))

/-! ## Selectors and specificity -/

inductive Selector where
  | type  : String → Selector
  | klass : String → Selector
  | id    : String → Selector
  | child : Selector → Selector → Selector
deriving Repr, DecidableEq

/-- CSS-like specificity `(ids, classes, types)`. -/
structure Spec where
  ids : Nat
  classes : Nat
  types : Nat
deriving Repr, DecidableEq

def Selector.spec : Selector → Spec
  | .type _    => ⟨0, 0, 1⟩
  | .klass _   => ⟨0, 1, 0⟩
  | .id _      => ⟨1, 0, 0⟩
  | .child a d =>
    let x := a.spec
    let y := d.spec
    ⟨x.ids + y.ids, x.classes + y.classes, x.types + y.types⟩

/-- Lexicographic comparison of specificities. -/
def Spec.cmp (a b : Spec) : Ordering :=
  lexThen (compare a.ids b.ids) (lexThen (compare a.classes b.classes) (compare a.types b.types))

/-! ## Nodes, rules, context -/

structure Node where
  type : String
  klass : Option String := none
  id : Option String := none
  children : List Node := []
deriving Repr

abbrev Context := List (String × String)

def ctxLookup (c : Context) (k : String) : Option String :=
  (c.find? (fun p => p.1 == k)).map (·.2)

structure Rule where
  selector : Selector
  props : List (String × String)
  cond : Option (String × String) := none   -- @dimension[value]
  order : Nat
  line : Nat
deriving Repr

def Rule.active (r : Rule) (c : Context) : Bool :=
  match r.cond with
  | none           => true
  | some (dim, val) => ctxLookup c dim == some val

/-- Selector matching against a node with its ancestor path (root → parent). -/
def matchSel : Selector → Node → List Node → Bool
  | .type t,    n, _   => n.type == t
  | .klass k,   n, _   => n.klass == some k
  | .id i,      n, _   => n.id == some i
  | .child a d, n, anc =>
    matchSel d n anc &&
    (match anc.getLast? with
     | none        => false
     | some parent => matchSel a parent (anc.dropLast))

/-! ## Cascade -/

structure Prec where
  spec : Spec
  order : Nat
deriving Repr, DecidableEq

/-- Precedence: specificity first, then source order. -/
def Prec.cmp (a b : Prec) : Ordering :=
  lexThen (Spec.cmp a.spec b.spec) (compare a.order b.order)

structure Contribution where
  value : String
  prec : Prec
  fromSel : Selector
  line : Nat
deriving Repr

structure Resolved where
  value : String
  fromSel : Selector
  line : Nat
deriving Repr, DecidableEq

/-- The cascade: pick the contribution with the greatest precedence. -/
def cascade : List Contribution → Option Resolved
  | []      => none
  | c :: cs =>
    let best := cs.foldl
      (fun acc x => match Prec.cmp x.prec acc.prec with | .gt => x | _ => acc) c
    some ⟨best.value, best.fromSel, best.line⟩

structure ResolvedNode where
  type : String
  klass : Option String
  id : Option String
  props : List (String × Resolved)
  children : List ResolvedNode
deriving Repr, Inhabited

def contributionsFor (rules : List Rule) (ctx : Context) (n : Node) (anc : List Node)
    : List (String × Contribution) :=
  concatMap
    (fun r => r.props.map (fun kv =>
      (kv.1, (⟨kv.2, ⟨r.selector.spec, r.order⟩, r.selector, r.line⟩ : Contribution))))
    (rules.filter (fun r => r.active ctx && matchSel r.selector n anc))

partial def resolveNode (rules : List Rule) (ctx : Context) (n : Node) (anc : List Node)
    : ResolvedNode :=
  let cs := contributionsFor rules ctx n anc
  let keys := nub (cs.map (·.1))
  let props := keys.filterMap (fun k =>
    match cascade ((cs.filter (·.1 == k)).map (·.2)) with
    | some r => some (k, r)
    | none   => none)
  ⟨n.type, n.klass, n.id, props, n.children.map (fun c => resolveNode rules ctx c (anc ++ [n]))⟩

def resolve (rules : List Rule) (ctx : Context) (forest : List Node) : List ResolvedNode :=
  forest.map (fun n => resolveNode rules ctx n [])

/-! ## The service example (mirrors `Examples/service.{hc,hcs}`) -/

def service : List Node :=
  [⟨"Service", none, none,
    [⟨"Logger", some "console", none, []⟩,
     ⟨"Database", none, some "main-db", [⟨"Connect", none, none, []⟩]⟩,
     ⟨"APIServer", none, none, [⟨"Listen", none, none, []⟩]⟩]⟩]

def sheet : List Rule :=
  [⟨.type "Logger",  [("level", "debug")],                      none,                    0, 1⟩,
   ⟨.klass "console", [("format", "text")],                     none,                    1, 4⟩,
   ⟨.type "Database", [("driver", "sqlite"), ("file", "dev.sqlite3")], none,             2, 6⟩,
   ⟨.child (.type "APIServer") (.type "Listen"), [("host", "127.0.0.1"), ("port", "5000")], none, 3, 9⟩,
   ⟨.type "Logger",  [("level", "info")],   some ("env", "production"),                   4, 12⟩,
   ⟨.klass "console", [("format", "json")], some ("env", "production"),                   5, 15⟩,
   ⟨.id "main-db",   [("driver", "postgres"), ("pool_size", "50")], some ("env", "production"), 6, 18⟩,
   ⟨.child (.type "APIServer") (.type "Listen"), [("host", "0.0.0.0"), ("port", "8080")], some ("env", "production"), 7, 21⟩]

def dev : List ResolvedNode := resolve sheet [] service
def prod : List ResolvedNode := resolve sheet [("env", "production")] service

partial def findNode : List ResolvedNode → String → Option ResolvedNode
  | [],      _  => none
  | n :: ns, ty =>
    if n.type == ty then some n
    else match findNode n.children ty with
         | some f => some f
         | none   => findNode ns ty

def propOf (rn : ResolvedNode) (k : String) : Option String :=
  (rn.props.find? (·.1 == k)).map (·.2.value)

/-! ## Oracle agreement (machine-checked against the Swift results) -/

-- Visible during `lake build`:
#eval (findNode dev "Logger").bind (propOf · "level")    -- some "debug"
#eval (findNode prod "Database").bind (propOf · "driver") -- some "postgres"

example : (findNode dev "Logger").bind (propOf · "level")     = some "debug"    := by native_decide
example : (findNode dev "Logger").bind (propOf · "format")    = some "text"     := by native_decide
example : (findNode dev "Database").bind (propOf · "driver")  = some "sqlite"   := by native_decide
example : (findNode prod "Logger").bind (propOf · "level")    = some "info"     := by native_decide
example : (findNode prod "Logger").bind (propOf · "format")   = some "json"     := by native_decide
-- specificity beats source order: #id "postgres" wins over type "sqlite"
example : (findNode prod "Database").bind (propOf · "driver") = some "postgres" := by native_decide
-- inherited, not overridden in production
example : (findNode prod "Database").bind (propOf · "file")   = some "dev.sqlite3" := by native_decide
-- source order within equal specificity (child > child)
example : (findNode prod "Listen").bind (propOf · "port")     = some "8080"     := by native_decide

/-! ## Order facts and totality (kernel-checked) -/

-- id ≻ class ≻ type
example : Spec.cmp ⟨1, 0, 0⟩ ⟨0, 1, 0⟩ = .gt := by decide
example : Spec.cmp ⟨0, 1, 0⟩ ⟨0, 0, 1⟩ = .gt := by decide
-- child selectors sum their components
example : (Selector.child (.type "A") (.type "B")).spec = ⟨0, 0, 2⟩ := by decide
-- `#id` ≻ `Type > Type` (specificity (1,0,0) ≻ (0,0,2))
example : Spec.cmp ⟨1, 0, 0⟩ ⟨0, 0, 2⟩ = .gt := by decide

/-- The cascade is total: a non-empty candidate list always resolves. -/
theorem cascade_total (cs : List Contribution) (h : cs ≠ []) : (cascade cs).isSome = true := by
  cases cs with
  | nil => exact absurd rfl h
  | cons _ _ => rfl

end Hypercode
