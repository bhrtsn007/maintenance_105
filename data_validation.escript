#!/usr/bin/env escript
% Sets all pps stations in debug mode

main(_) ->
	data_domain_check().


data_domain_check() ->
    net_kernel:start([shell, shortnames]),
    erlang:set_cookie(node(), butler_server),
    Data=rpc:call(erlang:list_to_atom("butler_server@localhost"),data_domain_validation_functions, validate_all_tables, [true]),
    io:format("Data domain is : (~p)",[Data]).
