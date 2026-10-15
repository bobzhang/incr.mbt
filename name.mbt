///|
/// Structural names used by typed cell stores, memo tables, and namespaces.
pub(all) enum Name {
  Unit
  Int(Int32)
  Text(String)
  Pair(Name, Name)
  Left(Name)
  Right(Name)
} derive(Eq, Hash, Debug)

///|
pub fn name_unit() -> Name {
  Unit
}

///|
pub fn name_of_int(value : Int32) -> Name {
  Int(value)
}

///|
pub fn name_of_string(value : String) -> Name {
  Text(value)
}

///|
pub fn name_pair(left : Name, right : Name) -> Name {
  Pair(left, right)
}

///|
pub fn name_fork(name : Name) -> (Name, Name) {
  (Left(name), Right(name))
}

///|
pub fn name_fork3(name : Name) -> (Name, Name, Name) {
  let (a, rest) = name_fork(name)
  let (b, c) = name_fork(rest)
  (a, b, c)
}

///|
pub fn name_fork4(name : Name) -> (Name, Name, Name, Name) {
  let (a, rest) = name_fork(name)
  let (b, c, d) = name_fork3(rest)
  (a, b, c, d)
}

///|
pub extend Name with Eq::{equal, not_equal}

///|
pub extend Name with Hash::{hash, hash_combine}

///|
pub extend Name with Debug::{to_repr}
