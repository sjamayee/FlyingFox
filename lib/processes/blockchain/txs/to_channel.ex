defmodule ToChannel do
  defstruct nonce: 0, to: "amount", amount: 0, new: false, delay: 100, fee: 10000, pub: "", pub2: ""
	def key(a, b) do
		cond do
			a > b -> a <> b
			true -> b <> a
		end
	end
	def check(tx, txs) do
    cond do
      not tx.data.to in ["amount", "amount2"] ->
				IO.puts("bad to #{inspect tx}")
				false
			tx.data.pub == nil ->
				IO.puts("nil pub #{inspect tx.data.pub}")
				false
			tx.data.pub2 == nil ->
				IO.puts("nil pub 2 #{inspect tx.data.pub2}")
				IO.puts("tx #{inspect tx}")
				false
			KV.get(tx.data.pub) == nil ->
				IO.puts("account hasn't been registered #{inspect tx.data.pub}")
				false
			KV.get(tx.data.pub2) == nil ->
				IO.puts("account hasn't been registered #{inspect tx.data.pub2}")
				false
			true -> check_2(tx, KV.get(key(tx.data.pub, tx.data.pub2)), txs)
		end
	end
	def check_2(tx, channel, txs) do
		cond do
		(channel == nil) and (tx.data.new != true) ->
				IO.puts("channel doesn't exist yet")
				false
		(channel != nil) and (tx.data.new == true) ->
				IO.puts("channel already exists")
				false
		(channel != nil) and (channel.nonce != 0) ->
				IO.puts("this channel is being closed.")
				false
    true -> true
    end
	end
	def update(tx, d) do
    da = tx.data
		channel = key(da.pub, da.pub2)
    TxUpdate.sym_increment(da.pub, :amount, -da.amount - da.fee, d)
		cb = %Channel{pub: da.pub,
									pub2: da.pub2,
									delay: da.delay}
		if da.new and d==1 do
			KV.put(channel, cb)
		end
    TxUpdate.sym_increment(channel, String.to_atom(da.to), da.amount, d)
		if da.new and d==-1 do KV.put(channel, nil)	end
		end
end