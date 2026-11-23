# NZBHydra2 Helm Chart

![Downloads](https://img.shields.io/github/downloads/tonylea/helm-chart-nzbhydra2/total)

Deploys [NZBHydra2](https://github.com/theotherp/nzbhydra2), a meta search for Usenet indexers, from LinuxServer's image, [`lscr.io/linuxserver/nzbhydra2`](https://github.com/linuxserver/docker-nzbhydra2).
Its maintainer's own test setup uses that image, and the project's `theotherp/nzbhydra2` image is amd64 only and years out of date.

The chart is opinionated: the API key, the login and the Usenet indexers come from values and Secrets, and are written to `nzbhydra.yml` at every start.
It runs one replica, and stops the old pod before starting the new one, since NZBHydra2 keeps its H2 database and its settings in `/config`, which has one writer.
The pod waits 120 seconds to stop, because a killed NZBHydra2 skips its shutdown cleanup and leaves the database larger.

The image starts as root, switches to `puid` and `pgid`, and keeps the default capabilities, because none of the project's images has a non-root mode.

## Values

| Value | Default |
| --- | --- |
| `image.tag` | the chart's `appVersion` |
| `initImage.repository` | `mikefarah/yq` |
| `initImage.tag` | `4.54.3` |
| `puid` | `1000` |
| `pgid` | `1000` |
| `timezone` | `UTC` |
| `apiKey.secretKeyRef.name` | none; required |
| `apiKey.secretKeyRef.key` | `api-key` |
| `auth.username.secretKeyRef.name` | none; required |
| `auth.username.secretKeyRef.key` | `username` |
| `auth.password.secretKeyRef.name` | none; required |
| `auth.password.secretKeyRef.key` | `password` |
| `indexers` | none; no indexers |
| `indexers[].name` | required |
| `indexers[].host` | required; the indexer's URL |
| `indexers[].apiKey.secretKeyRef.name` | required |
| `indexers[].apiKey.secretKeyRef.key` | required |
| `resources` | none |
| `persistence.config.existingClaim` | none; the chart creates a claim |
| `persistence.config.storageClassName` | the cluster's default class |
| `persistence.config.size` | `5Gi` |
| `httpRoute.enabled` | `false` |
| `httpRoute.parentRefs` | none; required when enabled |
| `httpRoute.hostnames` | none |

## Fixed settings

NZBHydra2 has no environment variables for its settings, so an init container sets these keys in `/config/nzbhydra.yml` at every start, and leaves every other key as it is.
If the file is missing, a first init container starts NZBHydra2 briefly so the app writes its own complete base config, and the settings edit then applies to that.
A change made to them in the web UI is lost at the next start.

- `main.apiKey`, from `apiKey`'s Secret.
- `auth.authType`, `FORM`, and `auth.users`, one user from `auth`'s Secrets.
  The password is written as `{noop}<password>`, the prefix NZBHydra2's password check needs for a plain value.
  Its four permissions, `maySeeAdmin`, `maySeeStats`, `maySeeDetailsDl` and `showIndexerSelection`, are all `true`.
- `indexers`, one Newznab entry for each item in `indexers`, enabled.
  Any other setting on an indexer, such as its categories, is reset at the next start.

NZBHydra2 rewrites the file after it starts and obfuscates the API keys and the username.
The init container writes them plain again at the next start.

The init container edits the file with [yq](https://github.com/mikefarah/yq), from the project's own image.
It runs as root with only the capabilities it needs to write a file that `puid` and `pgid` own.

## Requirements

- A Secret holding the API key, and one or two holding the login's username and password.
- A Secret key for each indexer's API key.
- A storage class for the claim the chart creates, the cluster's default unless named.
  The claim is `ReadWriteOnce`.
  Use a local disk, not a network file share, for `/config`: the H2 database is a single file.
- The Gateway API's `HTTPRoute` CRD, when `httpRoute.enabled` is set.

## Usage

```sh
helm repo add nzbhydra2 https://tonylea.github.io/helm-chart-nzbhydra2
helm install nzbhydra2 nzbhydra2/nzbhydra2 --values my-values.yaml
```

```yaml
timezone: Europe/London
apiKey:
  secretKeyRef:
    name: nzbhydra2
auth:
  username:
    secretKeyRef:
      name: nzbhydra2
  password:
    secretKeyRef:
      name: nzbhydra2
indexers:
  - name: example
    host: https://indexer.example.com
    apiKey:
      secretKeyRef:
        name: example-indexer
        key: api-key
persistence:
  config:
    existingClaim: nzbhydra2-config
```

## Development

Pull requests run:

- `helm lint --strict`, and the rendered chart checked by kubeconform against Kubernetes 1.37.
- helm-unittest's tests in `tests/`.
- An install with chart-testing in a kind cluster, against the Secrets from `ci/kind`.

Commits follow Conventional Commits.
Releases are versioned and tagged automatically from `main`, and published to the Helm repository on this repo's GitHub Pages.
