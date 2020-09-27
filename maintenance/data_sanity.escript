#!/usr/bin/env escript
% Sets all pps stations in debug mode

main(_) ->
	data_sanity_check().


data_sanity_check() ->
    net_kernel:start([shell, shortnames]),
    erlang:set_cookie(node(), butler_server),
    Data=rpc:call(erlang:list_to_atom("butler_server@localhost"),data_sanity_check_functions, check_complete_data_sanity, []),
    io:format("Data sanity is : (~p)",[Data]).
