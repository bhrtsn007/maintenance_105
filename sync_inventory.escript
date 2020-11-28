#!/usr/bin/env escript
% Sets all pps stations in debug mode

main(_) ->
	sync_inventory().


sync_inventory() ->
    net_kernel:start([shell, shortnames]),
    erlang:set_cookie(node(), butler_server),
    Data=rpc:call(erlang:list_to_atom("butler_server@localhost"),butler_test_functions, update_inventory_db_from_storage_nodes, []),
	io:format("Sync Inventory is : ~p~n",[Data]).