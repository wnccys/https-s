import gleam/bit_array
import gleam/int
import gleam/string
import gleam/io
import gleam/erlang/atom
import gleam/erlang/process
import gleam/dynamic.{type Dynamic}
import gleam/bytes_tree
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}

@external(erlang, "gen_tcp", "listen")
fn gen_tcp_listen(port: Int, options: List(Dynamic)) -> Result(Socket, Dynamic)

@external(erlang, "gen_tcp", "accept")
fn gen_tcp_accept(socket: Socket) -> Result(ClientSocket, a)

@external(erlang, "gen_tcp", "recv")
fn gen_tcp_recv(socket: ClientSocket, length: Int) -> Result(BitArray, a)

@external(erlang, "gen_tcp", "send")
fn gen_tcp_send(socket: ClientSocket, data: BitArray) -> a

@external(erlang, "gen_tcp", "close")
fn gen_tcp_close(socket: a) -> Result(Nil, b)

@external(erlang, "erlang", "decode_packet")
fn decode_packet(type_: atom.Atom, packet: BitArray, options: List(a)) -> Result(#(atom.Atom, b, BitArray), atom.Atom)

// Opaque type for TCP sockets
type Socket
type ClientSocket

fn start_server(handler: fn(Request(bytes_tree.BytesTree)) -> Response(bytes_tree.BytesTree)) {
  let port = 8080

  case gen_tcp_listen(port, []) {
    Ok(socket) -> {
      io.println("Socket is listening on port: " <> int.to_string(port))
      accept_loop(socket, handler)

      Ok(Nil)
    }
    Error(err) -> {
      io.println("An error occurred while start listening: " <> string.inspect(err))

      Error("Socket failed to listen.")
    }
  }
}

fn accept_loop(socket: Socket, handler: fn(Request(bytes_tree.BytesTree)) -> Response(bytes_tree.BytesTree)) {
  case gen_tcp_accept(socket) {
    Ok(client_socket) -> {
      process.spawn(fn() {
        gen_tcp_send(client_socket, bit_array.from_string("HTTP/1.1 200 OK\r\n\r\nhello"))
        gen_tcp_close(client_socket)
      })
      accept_loop(socket, handler)
    }
    Error(n) -> {
      io.println("Accept error: " <> string.inspect(n))
      let _ = gen_tcp_close(socket)

      Nil
    }
  }
}

fn handle_request(req: Request(String)) -> Response(String) { todo }

pub fn main() {
  let handler = fn(req) {
    response.new(200)
    |> response.set_body(bytes_tree.from_string("Hello, Gleam!"))
  }
  |> start_server()
}
