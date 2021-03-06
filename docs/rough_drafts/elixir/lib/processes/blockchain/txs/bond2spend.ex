defmodule Bond2Spend do
	defstruct nonce: 0, pub: ""
	def check(_, _) do true end
	def update(tx, d) do
    a = tx.data.amount
    b = KV.get("tot_bonds")
    KV.put("tot_bonds", b - (a * d))
    TxUpdate.sym_increment(tx.data.pub, :amount, a / TxUpdate.exchange_rate - tx.data.fee, d)
    TxUpdate.sym_increment(tx.data.pub, :bond, -a, d)
    #Users can take their money out of the bond at any time.
	end
end
