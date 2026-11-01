This is a web application written using the Phoenix web framework.

## Project guidelines

- API structure and OpenAPI rules live in `specs/api.md` at the repository root — follow them for any new endpoint
- The domain lives in `specs/connections.md`, `specs/variables.md`, `specs/funnels.md` and `specs/caching.md`; `CLAUDE.md` beside this file says where code goes
- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps
- Tests stub Meta and BigQuery with `Req.Test` (config/test.exs names the stub); the Postgres connector is tested against the test database itself (`PixelAudit.Api.Fixtures.test_database_url/0`)

### Syntax traps that have actually bitten this project

- **A dynamic map key must come BEFORE keyword-shorthand pairs.** Elixir requires
  the `key: value` shorthand to be last in a map or list literal, so mixing a
  computed key in earlier is a compile error — `unexpected expression after
  keyword list`. This has been written wrong twice here, both times in a
  `group_by |> Enum.map` that builds a claim map with a variable key.

      # WRONG — fails to compile
      %{resource_pool_id: pool_id, key => at, units: total}

      # RIGHT — the dynamic key leads
      %{key => at, resource_pool_id: pool_id, units: total}

  It fails loudly rather than silently, but it fails at the *file* level, so it
  can block the whole suite from running and make an unrelated change look
  broken. If `mix compile` reports it, look for a `=>` sitting after a `key:`.

- **A private helper cannot share a name and arity with an imported macro.** The
  import wins: your `defp` is never reached, the call site expands the macro
  instead, and the error names the macro's complaint rather than your function.
  This has bitten twice here, both times in a file whose `import` was three
  screens away from the call:

      # In a module with `import Ecto.Query`:
      defp update(plan, attrs), do: ...      # shadowed by Ecto.Query.update/2
      # => (Ecto.Query.CompileError) malformed update `attrs` in query expression

      # In a test case with `use ConnCase` (imports Phoenix.VerifiedRoutes):
      defp path(rule), do: ...               # shadowed by VerifiedRoutes.path/2
      # => expected compile-time ~p path string, got: rule

  The names to avoid are the common ones: `update`, `path`, `get`, `select`,
  `join`, `from`, `where`, `order_by`, `preload`, `delete`, `render`, `json`.
  When a compile error accuses you of misusing a macro you never called, look
  for a `defp` of that name in the same file. Give the helper a specific name
  (`apply_attrs`, `rule_path`) and leave a comment saying what it collided with,
  so nobody renames it back.

<!-- usage-rules-start -->

<!-- phoenix:elixir-start -->
## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests
  - Instead of sleeping to wait for a process to finish, **always** use `Process.monitor/1` and assert on the DOWN message:

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

   - Instead of sleeping to synchronize before the next call, **always** use `_ = :sys.get_state/1` to ensure the process has handled prior messages
<!-- phoenix:elixir-end -->

<!-- phoenix:phoenix-start -->
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it
<!-- phoenix:phoenix-end -->

<!-- phoenix:ecto-start -->
## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates, ie a message that needs to reference the `message.user.email`
- Remember `import Ecto.Query` and other supporting modules when you write `seeds.exs`
- `Ecto.Schema` fields always use the `:string` type, even for `:text`, columns, ie: `field :name, :string`
- `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such as option is never needed
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Fields which are set programmatically, such as `user_id`, must not be listed in `cast` calls or similar for security purposes. Instead they must be explicitly set when creating the struct
- **Always** invoke `mix ecto.gen.migration migration_name_using_underscores` when generating migration files, so the correct timestamp and conventions are applied
<!-- phoenix:ecto-end -->

<!-- usage-rules-end -->