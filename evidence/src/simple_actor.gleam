import gleam/io
import gleam/otp/actor
import gleam/erlang
import gleam/erlang/process

pub fn main() {
  let parent_subject = process.new_subject()

  let actor =
    actor.start_spec(actor.Spec(
      init: fn() {
        let final = "message from init function"
        process.send(parent_subject, final)
        actor.Ready(0, process.new_selector())
      },
      init_timeout: 1000,
      loop: fn(msg, state) {
        io.debug(" IN CHILD: loop function triggered")
        io.debug(" IN CHILD: Message from parent in loop: " <> msg)
        actor.Continue(state)
      },
    ))

  let assert Ok(actor_subject) = actor

  // get the message from the init function.
  let assert Ok(msg) = process.receive(parent_subject, 10)

  io.debug("IN PARENT: " <> msg)

  // send a message to the actor.
  process.send(actor_subject, "Hello from parent")

  let actor_pid = process.subject_owner(actor_subject)

  // wait for a second, let stdout run.
  process.sleep(1000)

  // wait, so we can use observer
  let _discard = erlang.get_line("press enter to terminate the actor")

  // send exit, is this out of band, not a standard message.
  process.send_exit(actor_pid)

  io.println("Press Ctrl-c a enter to exit.")
  
  Ok(process.sleep_forever())
}
