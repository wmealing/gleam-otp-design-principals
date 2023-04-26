import gleam/io
import gleam/int
import gleam/otp/actor
import gleam/erlang
import gleam/iterator.{fold, from_list, take}
import gleam/erlang/process.{Subject}

pub type Message {
  Target(Subject(Message))
  MsgNext(Int)
  NoTarget
}

pub type SystemState {
  NextInChain(Subject(Message))
  None
}

pub fn make_actor(parent_subject: Subject(a)) {
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
          MsgNext(i) -> {
            case state {
              NextInChain(target) -> {
                io.debug(i)
                case i {
                  0 -> {
                    actor.Continue(state)
                  }
                  _anything_else -> {
                    process.send(target, MsgNext(i - 1))
                    actor.Continue(state)
                  }
                }
              }

              None -> {
                io.debug("Reached end of the line.")
                actor.Continue(state)
              }
            }
          }
          NoTarget -> {
            io.debug("No target set..")
            actor.Continue(state)
          }
        }
      },
    )

  let assert Ok(actor) = actor.start_spec(actor_spec)

  actor
}

pub fn main() {
  let parent_subject = process.new_subject()

  // make 10 actors
  let actor_list =
    iterator.repeatedly(fn() { make_actor(parent_subject) })
    |> take(100)
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

  io.debug("FIRST ACTOR: ")

  let assert Ok(last_actor) =
    actor_list
    |> from_list
    |> iterator.at(99)

  let assert Ok(first_actor) =
    actor_list
    |> from_list
    |> iterator.at(1)

  // set the last actor to message the first.
  process.send(first_actor, Target(last_actor))

  // fire off the message to the ring.

  // m * n == 100
  process.send(last_actor, MsgNext(1000))

  io.debug(last_actor)

  Ok(process.sleep_forever())
}
