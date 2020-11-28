#!/usr/bin/env escript
% Sets all pps stations in debug mode

main(_) ->
        net_kernel:start([shell, shortnames]),
        erlang:set_cookie(node(), butler_server),
        ArchiveFun =
        fun
        F([], _) ->
        ok;
           F(Records, SourceTableName) ->
           RecordSize = erlang:length(Records),
                    BatchSize = rpc:call(erlang:list_to_atom("butler_server@localhost"),application, get_env, [butler_server, db_archive_batch_size, 1000]),
                    DestinationTableName = list_to_atom(atom_to_list(SourceTableName) ++ "_archive"),
                    RecordSizeToTransfer = min(RecordSize, BatchSize),
                    {RecordsToTransfer, RemainingRecords} = lists:split(RecordSizeToTransfer, Records),
                    G =
                    fun() ->
                        lists:foreach(
                          fun(Record) ->
                          DestinationRecord = erlang:setelement(1, Record, DestinationTableName),
                            ok = mnesia:write(DestinationRecord),
                            PrimaryKey = erlang:element(2, Record),
                            ok = rpc:call(erlang:list_to_atom("butler_server@localhost"),db_functions, db_delete_key, [SourceTableName, PrimaryKey])
                          end, RecordsToTransfer)
                        end,
            mnesia:transaction(G),
            F(RemainingRecords, SourceTableName)
            end,
        {ok,PpsTaskRecords}=rpc:call(erlang:list_to_atom("butler_server@localhost"),db_functions, get_record_by_where_clause, [ppstaskrec, [{status, equal, complete}]]),
        Result1=ArchiveFun(PpsTaskRecords, ppstaskrec),
        io:format("PPstaskrec: ~p~n",[Result1]),
        case Result1 of
        ok ->
            io:format("PPS Task record Cleanup completed successfully ,~p~n", [Result1]);
        badrpc ->
            io:format("Error occured in archiving ppstaskrec ,~p~n", [Result1]);
        _ ->
            io:format(" Something wrong happen PPS Task record Cleanup  ,~p~n", [Result1])
        end.
