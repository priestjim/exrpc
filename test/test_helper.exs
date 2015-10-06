ExUnit.start()
ExUnit.configure(seed: 0)
:net_kernel.start([{:longnames, true}, :'exrpc@127.0.0.1'])
