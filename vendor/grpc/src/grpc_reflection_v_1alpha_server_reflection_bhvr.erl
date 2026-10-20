%%%-------------------------------------------------------------------
%% @doc Behaviour to implement for grpc service grpc.reflection.v1alpha.ServerReflection.
%% @end
%%%-------------------------------------------------------------------

%% this module was generated and should not be modified manually

-module(grpc_reflection_v_1alpha_server_reflection_bhvr).

-callback server_reflection_info(grpc_stream:stream(), grpc:metadata())
    -> {ok, grpc_stream:stream()}.

