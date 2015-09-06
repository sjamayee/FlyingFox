%this should be redundant between hard drive and ram, that way we can be faster.
-module(block_pointers).
-behaviour(gen_server).
-export([start_link/0,code_change/3,handle_call/3,handle_cast/2,handle_info/2,init/1,terminate/2, read/2,write/2,test/0,height/0,append/1]).
-define(file, "block_pointers.db").
-define(word, 8).
init(ok) -> {ok, []}.
start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, ok, []).
code_change(_OldVsn, State, _Extra) -> {ok, State}.
terminate(_, _) -> io:format("died!"), ok.
handle_info(_, X) -> {noreply, X}.
handle_call(_, _From, D) -> {reply, 0, D}.
handle_cast({write, X, N}, D) -> 
    true = size(X) == ?word,
    {ok, File} = file:open(?file, [write, read, raw]),
    file:pwrite(File, N*?word, X),
    file:close(File),
    {noreply, D}.
write(X, N) -> gen_server:cast(?MODULE, {write, X, N}).
append(X) -> write(X, height()).
read(N, Many) -> 
    {ok, File } = file:open(?file, [read, binary, raw]),
    {ok, X} = file:pread(File, N*?word, Many*?word),
    file:close(File),
    X.
height() -> filelib:file_size(?file) div ?word.
test() -> 
    A = round(math:pow(2, 48)) - 1,
    C = <<A:48>>,
    B = <<"ABCD">>,
    X = << B/binary, C/binary >>,
    write(X, 2),
    write(<<"          ">>, 1),
    write(<<"asdfghjkl;">>, 0),
    timer:sleep(200),
    read(0, 3).

