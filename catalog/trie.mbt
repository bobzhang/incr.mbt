///|
priv enum TrieNode[T] {
  Empty
  Bucket(Int32, Array[T])
  Branch(Int32, Trie[T], Trie[T])
  Named(@incr.Name, Trie[T])
  Art(@incr.Art[Trie[T]])
}

///|
/// Persistent hash trie with named and articulated edit boundaries.
/// Equal hashes use equality-checked buckets, so collisions cannot lose elements.
pub struct Trie[T] {
  priv root : TrieNode[T]
}

///|
pub fn[T] Trie::empty() -> Trie[T] {
  { root: Empty, }
}

///|
pub fn[T] Trie::named(name : @incr.Name, child : Trie[T]) -> Trie[T] {
  { root: Named(name, child), }
}

///|
pub fn[T] Trie::art(art : @incr.Art[Trie[T]]) -> Trie[T] {
  { root: Art(art), }
}

///|
pub impl[T : Eq] Eq for Trie[T] with fn equal(self, other) {
  match (self.root, other.root) {
    (Empty, Empty) => true
    (Bucket(h, xs), Bucket(k, ys)) => h == k && xs == ys
    (Branch(bit, l, r), Branch(other_bit, ol, or)) =>
      bit == other_bit && l == ol && r == or
    (Named(n, t), Named(on, ot)) => n == on && t == ot
    (Art(a), Art(b)) => a == b
    _ => false
  }
}

///|
pub impl[T] Hash for Trie[T] with fn hash_combine(self, hasher) {
  match self.root {
    Empty => hasher.combine(0)
    Bucket(hash, values) => {
      hasher.combine(1)
      hasher.combine(hash)
      hasher.combine(values.length())
    }
    Branch(bit, l, r) => {
      hasher.combine(2)
      hasher.combine(bit)
      hasher.combine(l)
      hasher.combine(r)
    }
    Named(n, t) => {
      hasher.combine(3)
      hasher.combine(n)
      hasher.combine(t)
    }
    Art(a) => {
      hasher.combine(4)
      hasher.combine(a)
    }
  }
}

///|
pub extend Trie with Eq::{equal, not_equal}

///|
pub extend Trie with Hash::{hash, hash_combine}

///|
fn[T : Eq] Trie::insert_at(
  self : Trie[T],
  value : T,
  hash : Int32,
  depth : Int32,
) -> Trie[T] {
  match self.root {
    Empty => { root: Bucket(hash, [value]), }
    Bucket(old_hash, values) =>
      if old_hash == hash {
        if values.contains(value) {
          self
        } else {
          let next = values.copy()
          next.push(value)
          { root: Bucket(hash, next), }
        }
      } else {
        let empty = Trie::empty()
        let branch = if (old_hash & (1 << depth)) == 0 {
          { root: Branch(depth, self, empty), }
        } else {
          { root: Branch(depth, empty, self), }
        }
        branch.insert_at(value, hash, depth)
      }
    Branch(bit, left, right) =>
      if (hash & (1 << bit)) == 0 {
        { root: Branch(bit, left.insert_at(value, hash, bit + 1), right), }
      } else {
        { root: Branch(bit, left, right.insert_at(value, hash, bit + 1)), }
      }
    Named(n, tree) => Trie::named(n, tree.insert_at(value, hash, depth))
    Art(art) => art.force().insert_at(value, hash, depth)
  }
}

///|
pub fn[T : Hash + Eq] Trie::add(self : Trie[T], value : T) -> Trie[T] {
  self.insert_at(value, Hash::hash(value), 0)
}

///|
pub fn[T : Hash + Eq] Trie::contains(self : Trie[T], value : T) -> Bool {
  let hash = Hash::hash(value)
  for tree = self {
    match tree.root {
      Empty => break false
      Bucket(h, values) => break h == hash && values.contains(value)
      Branch(bit, left, right) =>
        continue if (hash & (1 << bit)) == 0 { left } else { right }
      Named(_, child) => continue child
      Art(art) => continue art.force()
    }
  }
}

///|
pub fn[T : Eq, R] Trie::fold(
  self : Trie[T],
  initial : R,
  body : (T, R) -> R,
) -> R {
  let mut result = initial
  let pending = [self]
  while pending.pop() is Some(tree) {
    match tree.root {
      Empty => ()
      Bucket(_, values) =>
        for value in values {
          result = body(value, result)
        }
      Branch(_, left, right) => {
        pending.push(right)
        pending.push(left)
      }
      Named(_, child) => pending.push(child)
      Art(art) => pending.push(art.force())
    }
  }
  result
}

///|
pub fn[T : Eq] Trie::is_empty(self : Trie[T]) -> Bool {
  self.fold(true, (_, _) => false)
}

///|
pub fn[T : Hash + Eq] Trie::from_list(list : List[T]) -> Trie[T] {
  list.fold(Trie::empty(), (x, set) => set.add(x))
}

///|
/// Compare set contents independently of collision-bucket order, names, and
/// articulation identities. Unlike structural equality, this forces contents.
pub fn[T : Hash + Eq] Trie::same_elements(
  self : Trie[T],
  other : Trie[T],
) -> Bool {
  let (count, included) = self.fold((0, true), (x, acc) => {
    (acc.0 + 1, acc.1 && other.contains(x))
  })
  included && count == other.fold(0, (_, count) => count + 1)
}
