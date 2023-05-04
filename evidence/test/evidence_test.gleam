import distribution.{start}
import gleam/io

import gleeunit
import gleeunit/should


pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  1
  |> should.equal(1)
}

pub fn distribution_starts_test() {
  let out = start("sam")
}


pub fn cookie_setting_works_test() {
 distribution.set_cookie("ABCDEFGJKLMN")
 let cookie = distribution.get_cookie()

 cookie
 |> should.equal("ABCDEFGJKLMN")
}
