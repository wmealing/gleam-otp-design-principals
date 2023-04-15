
import gleam/io
import gleam/int
import gleam/list
import gleam/erlang/process.{Subject}
import gleam/result
import gleam/function
import gleam/iterator.{iterate, take, to_list}


pub type ChannelResponse {
  Allocated(id: Int)
  None
  ChildSubject(Subject(ChannelRequest))
}

pub type ChannelRequest {
   Allocate
   Show
   Free(ChannelResponse)
}

pub fn alloc(target, mine ) {
   process.send(target, Allocate)
   let assert Ok(allocation) = process.receive(mine, within: 1000)
   allocation
}

pub fn free(target, _mine, channel) {
   process.send(target, Free(channel))
}

pub fn show(target, _mine) {
   process.send(target, Show)
}

// generate a list of 100 channels for init.
pub fn generate_channel_list() {
 iterate(1, fn(n) { 1+n }) |> take(100) |> to_list
}

pub fn main() {
  io.println("Hello from non_gen_server!")

  // similar to a channel between the process to start
  let my_subject = process.new_subject()

  let thing = fn() { init(my_subject)}

  let assert _pid = process.start(running: thing, linked: True)

  // the channel from the child
  let assert ChildSubject(child_subject)=
    process.receive(my_subject, within: 100_000_000)
    |> result.unwrap(None)

  // show the default channels.
  show(child_subject, my_subject)

  // get three channels.
  let channel1 = alloc(child_subject, my_subject)
  let channel2 = alloc(child_subject, my_subject)
  let channel3 = alloc(child_subject, my_subject)

  // use the channels here.
  // use_channels(channel1, channel2, channel3)

  // show the free channel list:
  show(child_subject, my_subject)

  // return the channels, as we're done with them.
  free(child_subject, my_subject, channel1)
  free(child_subject, my_subject, channel2)
  free(child_subject, my_subject, channel3)

  // show the newly used list, they will be out of order.
  show(child_subject, my_subject)

  Ok(process.sleep_forever())
}

pub fn init(parent_subject: Subject(ChannelResponse)) {

  // create another subject, that other processes can use
  // to address this new process.
  let my_subject = process.new_subject()

  // send the new subject back to the parent, using its subject.
  process.send(parent_subject, ChildSubject(my_subject))

  // start the main process loop
  loop(my_subject, parent_subject, generate_channel_list())
}

pub fn loop(my_subject: Subject(ChannelRequest), parent_subject: Subject(ChannelResponse), channels: List(Int)) {

  // add a selector to listen from parent process.
  let sel =
    process.new_selector()
    |> process.selecting(for: my_subject, mapping: function.identity )

  // block forever on waiting for a message.
  let msg = process.select_forever(sel)

  let new_channels =  case msg {
     Allocate() -> {
       // choose the first value, return rest for new state
       let [next_available, .. rest ] = channels
       process.send(parent_subject, Allocated(next_available))
       io.debug("allocating channel " <> int.to_string(next_available) )
       rest
     }
     Free(id) -> {
      let assert Allocated(channel) = id
      io.debug("Freeing channel: " <> int.to_string(channel))
      list.append([channel], channels)
     }
     Show -> {
      io.debug("Available channels: !")
      io.debug(channels)
      channels
     }
  }

  loop(my_subject, parent_subject, new_channels)
}



