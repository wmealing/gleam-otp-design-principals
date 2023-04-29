import gleam/io

import gleam/otp/actor
import gleam/iterator.{fold, from_list, take}
import gleam/erlang.{start_arguments}
import gleam/erlang/process.{Subject}
import glint.{CommandInput}
import glint/flag

// Write a ring benchmark. Create N processes in a ring. Send a message round the ring M
// times so that a total of N * M messages get sent. Time how long this takes for different
// values of N and M.

// the key for the loop flag (M)
const loop = "loop"

// the key for the process-count flag (N)
const process_count = "process-count"

// terminate the vm,  i can't find a better way.
pub external fn terminate() -> Nil =
  "erlang" "halt"

pub type Message {
  Target(Subject(Message))
  MsgNext(Int)
  NoTarget
}

pub type SystemState {
  NextInChain(Subject(Message))
  None
}

pub fn handle_msg_next(state, count) {
  case state {
    NextInChain(target) -> {
      case count {
        0 -> {
          terminate()
          actor.Continue(state)
        }
        _anything_else -> {
          process.send(target, MsgNext(count - 1))
          actor.Continue(state)
        }
      }
    }
    None -> {
      actor.Continue(state)
    }
  }
}

pub fn make_actor() {
  let actor_spec =
    actor.Spec(
      init: fn() { actor.Ready(None, process.new_selector()) },
      init_timeout: 1000,
      loop: fn(msg: Message, state) {
        case msg {
          Target(t) -> {
            let newstate = NextInChain(t)
            actor.Continue(newstate)
          }
          MsgNext(count) -> {
            handle_msg_next(state, count)
          }
          NoTarget -> {
            actor.Continue(state)
          }
        }
      },
    )

  let assert Ok(actor) = actor.start_spec(actor_spec)

  actor
}

pub fn main() {
  let loop_flag =
    flag.I
    |> flag.default(10)
    |> flag.new
    |> flag.description("Loop the ring n times.")

  let process_count_flag =
    flag.I
    |> flag.default(1000)
    |> flag.new
    |> flag.description("Create N processes in a ring")

  glint.new()
  |> glint.add(
    at: [],
    do: glint.command(build_args)
    |> glint.flag(loop, loop_flag)
    |> glint.flag(process_count, process_count_flag)
    |> glint.description("Runs Joe Armstrongs ring benchmark"),
  )
  |> glint.run_and_handle(
    start_arguments(),
    fn(res) {
      case res {
        Ok(_out) -> {
          io.debug("looks good - OKAY")
        }
        Error(err) -> {
          err
        }
      }
      |> io.println
    },
  )
}

fn build_args(input: CommandInput) {
  let assert Ok(loop) = flag.get_int(from: input.flags, for: loop)
  let assert Ok(process_count) =
    flag.get_int(from: input.flags, for: process_count)


  // make 10 actors
  let actor_list =
    iterator.repeatedly(fn() { make_actor() })
    |> take(process_count)
    |> iterator.to_list()

  actor_list
  |> from_list
  |> fold(
    from: NoTarget,
    with: fn(prev, element) {
      process.send(element, prev)
      Target(element)
    },
  )

  let assert Ok(last_actor) =
    actor_list
    |> from_list
    |> iterator.last()

  let assert Ok(first_actor) =
    actor_list
    |> from_list
    |> iterator.first()

  // set the last actor to message the first.
  process.send(first_actor, Target(last_actor))

  // fire off the message to the ring.
  process.send(last_actor, MsgNext(process_count * loop))

  let assert _discard = Ok(process.sleep_forever())

  Ok("Ring Complete")
}
