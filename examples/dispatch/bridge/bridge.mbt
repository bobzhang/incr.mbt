///|
let session : Ref[@model.Session?] = Ref(None)

///|
#export_name("reset")
pub fn reset() -> String {
  if session.val is Some(old) {
    old.dispose()
  }
  let current = @model.Session()
  session.val = Some(current)
  current.read().to_json().stringify()
}

///|
#export_name("update")
pub fn update(kind : Int32, index : Int32, value : Int32) -> String {
  let current = session.val.unwrap()
  current.update(kind, index, value)
  current.read().to_json().stringify()
}
