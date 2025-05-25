package main

TODO :: proc() -> ! {
  panic("TODO")
}

contains :: proc($T: typeid, slice: []T, elem: T) -> bool {
	for test in slice {
		if test == elem {return true}
	}
	return false
}
