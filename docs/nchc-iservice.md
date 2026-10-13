# NCHC iService and RAP credentials

This guide configures two things:

1. **Nano4 SSH access** through iService, including your Supercomputer account,
   password, phone OTP, and Project system code.
2. **A RAP API key** for using models through OpenCode or Pi.

Complete the Nano4 website steps yourself. Enter machine passwords and OTP codes
only into SSH. Your mentor provides the team's RAP API key in your team Slack
channel. You may give this rotatable key to the agent. Keep keys out of Git and logs.

## 1. Nano4 SSH credentials

Complete these website steps yourself before submitting Nano4 jobs. Your local
agent can guide you through them. Sign in to
[NCHC iService](https://iservice.nchc.org.tw/nchc_service/index.php) and open
**Member Center → Member Profile → System Account (會員中心 → 會員資訊 → 主機帳號資訊)**:

1. Set up your **Supercomputer account (主機帳號)** for Nano4.
2. Set your **Supercomputer password (主機密碼)** for SSH login.
3. Create an **OTP Token** using **create user otp (建立OTP載具)**. Follow the registration email
   to set up the authentication app on your phone.

**The Supercomputer (machine) password is different from your iService website
password. Use the machine password for SSH. Do not confuse the two.**

See the [NCHC OTP setup guide](https://iservice.nchc.org.tw/nchc_service/nchc_service_qa_single.php?qa_code=774)
for phone registration and login instructions, and the
[Nano4 login setup](https://man.twcc.ai/@nano4-manual/rydOv6-Dbl) for account and
password setup. Keep your password, OTP registration details, and codes private.

Have these two identifiers ready for the agent or manual setup:

- `NCHC_ISERVICE_SUPERCOMPUTER_ACCOUNT`: your approved Supercomputer account username,
  shown under Supercomputer account details. This is your SSH username.
- `NCHC_ISERVICE_PROJECT_SYSTEM_CODE`: the **Project system code** for your
  Nano4-enabled project. Find it in **Member Center → Projects → My Projects (會員中心 → 計畫管理 → 我的計畫)**.
  Look up **NCHC-NVIDIA Joint Lab 教育訓練**, the Project system code should be `GOV114072`.
  Nano4's [job submission examples](https://man.twcc.ai/@nano4-manual/BkRXxZ_JMg)
  use this code for Slurm's `--account` option.

For Nano4 account or project access issues, ask [#cluster-support](https://nchcopenhackathon2026.slack.com/archives/C0C749A0NTE).

## 2. RAP API key

Your team's key is pre-created. Your NVIDIA mentor shares it in your team Slack
channel. Ask your mentor if you cannot find it. For RAP key or access issues,
ask [#cluster-support](https://nchcopenhackathon2026.slack.com/archives/C0C749A0NTE).

### Enter the key locally

You may give the RAP API key to the agent. It stores the key in the client's
private auth file with mode `600`, preserving other credentials. This is separate
from the model/settings files that the setup scripts configure.

For manual entry, use your client's local prompt after configuring the provider:

- **OpenCode:** start `opencode`, run `/connect`, choose **Other**, and enter
  provider ID `nchc-rap`, then your API key. It is stored in
  `~/.local/share/opencode/auth.json`.
- **Pi:** start `pi`, run `/login`, choose **API key**, and select **NCHC RAP**.
  Enter your key. Pi stores it in `~/.pi/agent/auth.json`.

If the client is already authenticated, skip entry and run the response test.
The Nano4 `secrets/.env` contains only the Supercomputer account and Project
system code. Keep passwords and OTP codes out of files, and API keys in the
client's private credential store.

## Appendix: RAP portal

The normal workflow uses your team's provided key. Use the portal when you need
to check providers, models, or key settings:

1. Sign in to [RAP Portal](https://portal.genai.nchc.org.tw/projects) and select
   the project indicated by your mentor.
2. Open **Model catalog (模型)** and check the exact model ID, image support,
   and API base URL. Models vary across providers. The default example is `Kimi-K3`.
3. Open **API Keys (API 金鑰)** to inspect key settings. Coordinate key creation
   or rotation with your mentor or `#cluster-support`.

See the [RAP manual](https://rap.genai.nchc.org.tw/doc) for portal and API details.

### Check the key (optional)

The portal's question mark shows an example for listing models. To check your
key, run these commands in your own Bash terminal. The hidden prompt keeps the
key out of shell history, and the header is passed through stdin:

```bash
read -r -s -p 'RAP API key: ' rap_api_key
printf '\n'
printf 'Authorization: Bearer %s\n' "$rap_api_key" |
  curl --fail --silent --show-error \
    -H 'Content-Type: application/json' -H @- \
    https://portal.genai.nchc.org.tw/api/v1/models
unset rap_api_key
```

Use your provider's base URL if it differs from the example.

[Continue in README: run jobs on Nano4](../README.md#3-run-jobs-on-nano4).
