%this module needs to keep track of the highest-nonced transaction recieved in each channel.

-module(channel_manager).
-behaviour(gen_server).
-export([start_link/0,code_change/3,handle_call/3,handle_cast/2,handle_info/2,init/1,terminate/2, unlock_hash/3,hashlock/3,spend/2,recieve/3,read/1,new_channel/2,first_cb/2,recieve_locked_payment/2,spend_locked_payment/2,delete/1,id/1,keys/0,create_unlock_hash/2]).
-record(f, {channel = [], unlock = []}).
init(ok) -> {ok, dict:new()}.
start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, ok, []).
code_change(_OldVsn, State, _Extra) -> {ok, State}.
terminate(_, _) -> io:format("died!"), ok.
handle_info(_, X) -> {noreply, X}.
handle_cast({store, N, Ch}, X) -> 
    {noreply, dict:store(N, Ch, X)};
handle_cast({delete, N}, X) -> 
    {noreply, dict:erase(N, X)}.
handle_call({read, N}, _From, X) -> 
    {reply, dict:fetch(N, X), X};
handle_call(keys, _From, X) -> 
    {reply, dict:fetch_keys(X), X}.
repeat(Times, X) -> repeat(Times, X, []).
repeat(0, _, Out) -> Out;
repeat(Times, X, Out) -> repeat(Times-1, X, [X|Out]).
keys() -> gen_server:call(?MODULE, keys).
id(Partner) -> id_helper(Partner, keys(), []).
id_helper(_, [], Out) -> Out;
id_helper(Partner, [Key|T], Out) ->
    F = read(Key),
    Ch = sign:data(F#f.channel),
    Acc1 = channel_block_tx:acc1(Ch),
    Acc2 = channel_block_tx:acc2(Ch),
    NewOut = if
	((Partner == Acc1) or (Partner == Acc2)) -> [Key|Out];
	true -> Out
	     end,
    id_helper(Partner, T, NewOut).

store(ChId, F) -> 
    gen_server:cast(?MODULE, {store, ChId, F}).

new_channel(ChId, Channel) -> 
    Ch = channel_block_tx:channel_block_from_channel(ChId, Channel, 0, 1, constants:max_reveal()-1, 0, []),
    F = #f{channel = Ch, unlock = []},
    store(ChId, F).

first_cb(ChId, CB) ->
    Old = read(ChId),
    true = is_record(f, Old),
    F = #f{channel = CB, unlock = repeat(length(channel_block_tx:bets(CB)), 28)},
    store(ChId, F).
    
is_in(_, []) -> false;
is_in(X, [X|_]) -> true;
is_in(X, [_|T]) -> is_in(X, T).

read(ChId) -> 
    K = keys(),
    true = is_in(ChId, K),
    gen_server:call(?MODULE, {read, ChId}).
delete(ChId) -> gen_server:call(?MODULE, {delete, ChId}).
spend(ChId, Amount) ->
    F = read(ChId),
    Ch = sign:data(F#f.channel),
    keys:sign(channel_block_tx:update(Ch, Amount, 1)).
match_n(X, Bets) -> match_n(X, Bets, 0).
match_n(X, [Bet|Bets], N) ->
    Y = language:extract_sh(channel_block_tx:bet_code(Bet)),
    if
        X == Y -> N;
        true -> match_n(X, Bets, N+1)
    end.
replace_n(N, New, L) -> replace_n(N, New, L, []).
replace_n(0, New, [_|L], Out) -> 
    lists:reverse(Out) ++ [New] ++ L;
replace_n(N, New, [H|L], Out) -> 
    replace_n(N-1, New, L, [H|Out]).
remove_nth(N, Bets) -> remove_nth(N, Bets, []).
remove_nth(0, [_|Bets], Out) -> lists:reverse(Out) ++ Bets;
remove_nth(N, [B|Bets], Out) -> remove_nth(N, Bets, [B|Out]).
create_unlock_hash(ChId, Secret) ->
    {SignedCh, _} = common(ChId, Secret),
    SignedCh.
nth(0, [X|_]) -> X;
nth(N, [_|T]) -> nth(N-1, T).
common(ChId, Secret) ->
    SecretHash = hash:doit(Secret),
    F = read(ChId),
    OldCh = sign:data(F#f.channel),
    Bets = channel_block_tx:bets(OldCh),
    N = match_n(SecretHash, Bets),%if the bets were numbered in order, N is the bet we are unlocking.
    Bet = nth(N, Bets),
    BetCode = channel_block_tx:bet_code(Bet),
    io:fwrite("bet "),
    io:fwrite(packer:pack(BetCode)),
    io:fwrite("\n"),
    Amount = language:valid_secret(Secret, BetCode),
    NewBets = remove_nth(N, Bets),
    NewCh = channel_block_tx:replace_bet(OldCh, NewBets),
    NewNewCh = channel_block_tx:update(NewCh, Amount, 1),
    %we need to change amount.
    {keys:sign(NewNewCh), N}.
unlock_hash(ChId, Secret, SignedCh) ->
    {SignedCh2, N} = common(ChId, Secret),
    NewCh = sign:data(SignedCh2),
    io:fwrite("signch "),
    io:fwrite(packer:pack(SignedCh)),
    io:fwrite("\n"),
    NewCh = sign:data(SignedCh),
    F = read(ChId),
    NewUnlock = replace_n(N, Secret, F#f.unlock),
    %channel_block_tx:add,
    NewF = #f{channel = SignedCh, unlock = NewUnlock},
    store(ChId, NewF),
    keys:sign(NewCh).
hashlock(ChId, Amount, SecretHash) ->
    F = read(ChId),
    Ch = sign:data(F#f.channel),
    Ch2 = channel_block_tx:update(Ch, Amount div 2, 1),
    Channel = block_tree:channel(ChId),
    Acc1 = channels:acc1(Channel),
    Acc2 = channels:acc2(Channel),
    MyAccount = case keys:id() of
            Acc1 -> 1;
            Acc2 -> 0
        end,
    Script = language:hashlock(MyAccount, SecretHash),
    keys:sign(channel_block_tx:add_bet(Ch2, Amount div 2, Script)).
%NewF = #f{channel = Ch3, unlock = [[1]|F#f.unlock]},
%store(ChId, NewF).
recieve_locked_payment(ChId, SignedChannel) ->
    general_locked_payment(ChId, SignedChannel, false).
spend_locked_payment(ChId, SignedChannel) ->
    general_locked_payment(ChId, SignedChannel, true).
general_locked_payment(ChId, SignedChannel, Spend) ->
    NewCh = sign:data(SignedChannel),
    true = channel_block_tx:is_cb(NewCh),
    F = read(ChId),
    Ch = sign:data(F#f.channel),
    NewAmount = channel_block_tx:amount(NewCh),
    OldAmount = channel_block_tx:amount(Ch),
    NewN = channel_block_tx:nonce(NewCh),
    OldN = channel_block_tx:nonce(Ch),
    Channel = block_tree:channel(ChId),
    A = NewAmount - OldAmount,
    N = NewN - OldN,
    true = N > 0,%error here.
    Ch2 = channel_block_tx:update(Ch, A, N),
    Acc1 = channels:acc1(Channel),
    Acc2 = channels:acc2(Channel),
    ID = keys:id(),
    ToAmount = if
	Spend -> 
	    case ID of Acc1 -> 1; Acc2 -> 0 end;
	true ->
	    case ID of
		Acc1 -> true = A > 0, 0;
		Acc2 -> true = A < 0, 1
	    end
    end,
    SecretHash = language:extract_sh(channel_block_tx:bet_code(hd(channel_block_tx:bets(NewCh)))),
    Script = language:hashlock(ToAmount, SecretHash),
    NewCha = channel_block_tx:add_bet(Ch2, A, Script),%this ensures that they didn't adjust anything else in the channel besides the amount and nonce and bet.
    NewCh = NewCha,
    NewF = #f{channel = SignedChannel, unlock = [[28]|F#f.unlock]},
    store(ChId, NewF),
    keys:sign(NewCh).

recieve(ChId, MinAmount, SignedPayment) ->
    %we need to verify that the other party signed it.
    ID = keys:id(),
    Payment = sign:data(SignedPayment),
    A1 = channel_block_tx:acc1(Payment),
    A2 = channel_block_tx:acc2(Payment),
    Acc1 = block_tree:account(A1),
    Acc2 = block_tree:account(A2),
    Pub1 = accounts:pub(Acc1),
    Pub2 = accounts:pub(Acc2),
    true = case ID of
	A1 -> sign:verify_2(SignedPayment, Pub2);
	A2 -> sign:verify_1(SignedPayment, Pub1)
    end,
    true = channel_block_tx:is_cb(Payment),
    F = read(ChId),
    Ch = sign:data(F#f.channel),
    NewAmount = channel_block_tx:amount(Payment),
    OldAmount = channel_block_tx:amount(Ch),
    NewN = channel_block_tx:nonce(Payment),
    OldN = channel_block_tx:nonce(Ch),
    Channel = block_tree:channel(ChId),
    A = NewAmount - OldAmount,
    N = NewN - OldN,
    true = N > 0,
    Payment = channel_block_tx:update(Ch, A, N),%this ensures that they didn't adjust anything else in the channel besides the amount and nonce.
    BTA1C = channels:acc1(Channel),
    BTA2C = channels:acc2(Channel),
    B = case ID of
        BTA1C -> A;
        BTA2C -> -A
    end,
    true = B > MinAmount - 1,
    NewF = #f{channel = SignedPayment, unlock = F#f.unlock},
    store(ChId, NewF),
    keys:sign(Payment).
    
    
    