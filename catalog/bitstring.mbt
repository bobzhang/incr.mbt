///|
/// A length/value pair so leading zero bits remain significant (maximum 30 bits).
pub struct BitString {
  length : Int32
  value : Int32
} derive(Eq, Hash, Debug)

///|
pub extend BitString with Eq::{equal, not_equal}

///|
pub extend BitString with Hash::{hash, hash_combine}

///|
pub extend BitString with Debug::{to_repr}

///|
pub fn BitString::BitString(length : Int32, value : Int32) -> BitString {
  guard length >= 0 && length <= 30 else {
    abort("bit string length must be between 0 and 30")
  }
  guard value >= 0 && value < 1 << length else {
    abort("value does not fit bit string")
  }
  { length, value, }
}

///|
/// Prepend a most significant bit. The argument must be 0 or 1.
pub fn BitString::prepend(self : BitString, bit : Int32) -> BitString {
  guard bit == 0 || bit == 1 else { abort("expected a bit") }
  BitString(self.length + 1, self.value | (bit << self.length))
}

///|
pub fn BitString::is_set(self : BitString, index : Int32) -> Bool {
  index >= 0 && index < self.length && (self.value & (1 << index)) != 0
}

///|
pub fn BitString::flip(self : BitString, index : Int32) -> BitString {
  guard index >= 0 && index < self.length else {
    abort("bit index out of range")
  }
  BitString(self.length, self.value ^ (1 << index))
}

///|
/// Logical left shift within the original bit width.
pub fn BitString::shift_left(self : BitString, count : Int32) -> BitString {
  guard count >= 0 else { abort("negative shift") }
  let value = if count >= self.length {
    0
  } else {
    (self.value << count) & ((1 << self.length) - 1)
  }
  BitString(self.length, value)
}
