begin;

    -- Create a new non-superuser role to manipulate permissions
    create role api;
    grant usage on schema graphql to api;

    -- Create minimal Query function
    create function public.get_one()
        returns int
        language sql
        immutable
        as
    $$
        select 1;
    $$;

    savepoint a;

    -- Use api role
    set role api;

    -- Confirm that getOne is visible to the api role
    select jsonb_pretty(
        graphql.resolve($$
        {
          __type(name: "Query") {
            fields {
              name
            }
          }
        }
        $$)
    );

    -- Execute
    select jsonb_pretty(
        graphql.resolve($$
            { getOne }
        $$)
    );

    -- revert to superuser
    rollback to savepoint a;
    select current_user;

    -- revoke default access from the public role for new functions
    -- this is not actually necessary for this test, but including here
    -- as a best practice in case this test is used as a reference
    alter default privileges revoke execute on functions from public;
    -- explicitly revoke execute from api role
    revoke execute on function public.get_one from api;
    -- api inherits from the public role, so we need to revoke from public too
    revoke execute on function public.get_one from public;

    -- Use api role w/o execute permission on get_one
    set role api;

    -- confirm we're using the api role
    select current_user;

    -- confirm that api can not execute get_one()
    select pg_catalog.has_function_privilege('api', 'get_one()', 'execute');

    -- Confirm getOne is not visible in the Query type
    select jsonb_pretty(
        graphql.resolve($$
        {
          __type(name: "Query") {
            fields {
              name
            }
          }
        }
        $$)
    );

    -- Confirm getOne can not be executed / is not found during resolution
    select jsonb_pretty(
        graphql.resolve($$
            { getOne }
        $$)
    );

rollback;
