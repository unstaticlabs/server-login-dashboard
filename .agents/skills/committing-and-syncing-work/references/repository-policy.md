# Repository Git policy

Store repository-wide agent preferences at `.usl/agent-policy.json`:

```json
{
  "version": 1,
  "git": {
    "auto_commit": true,
    "auto_push": "non-default"
  }
}
```

`auto_commit` is a boolean. `auto_push` is one of:

- `never`: pushing requires a current explicit request;
- `non-default`: automatic pushing is allowed only away from the remote's default branch;
- `always`: automatic pushing is allowed on any branch.

The policy is repository-specific and normally versioned so different agents apply the same choice. Do not silently repair, widen, or migrate an invalid policy. Explain the invalid field and ask for the intended value.

Precedence for the current task:

1. higher-priority safety and authorization rules;
2. the user's current explicit instruction;
3. the repository policy;
4. no automatic commit or push.

A one-task override does not rewrite the saved policy. An empty remote has no default branch, so its first publication always requires an explicit bootstrap decision.
