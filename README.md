# Single File Rails App

It is a POC for a Rails Web App in a Single File.

## Environment Variables

Rails
- `RAILS_ENV`, default: `development`
- `SECRET_KEY_BASE`, it is required in production environment.

You can use `SecureRandom.hex(64)` to generate one, for example:
```bash
ruby -r "securerandom" -e "puts SecureRandom.hex(64)"
```

Puma(Optional)
- `RAILS_MAX_THREADS`, default: `5`
- `RAILS_MIN_THREADS`, default: `5`
- `WEB_CONCURRENCY`, default: `Concurrent.physical_processor_count`
- `PORT`, default: `3000`
- `PIDFILE`, default: `tmp/server.pid`

You can also use the `.env` file to define environment variables.

## Start Application

Makefile
```bash
make
```

Ruby
```bash
ruby app.rb
```

## Restart Application

```bash
touch tmp/restart.txt
```

## k6 test

[Install k6](https://grafana.com/docs/k6/latest/set-up/install-k6/)

Run test
```bash
k6 run k6.js
```
