# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [1.0.4] - Unreleased
### Fixed
- Do not let VerneMQ container start unless the CA cert is retrieved from CFSSL.
- Prevent the connection from timing out when the client takes more than 5 seconds to perform the
  SSL handshake

## [1.0.3] - 2022-04-07

## [1.0.2] - 2022-03-30

## [1.0.1] - 2021-12-16
### Fixed
- Do not override VerneMQ config `max_message_rate` value.

## [1.0.0] - 2021-06-30
### Changed
- Log plugin version when the application is starting.

## [1.0.0-rc.0] - 2021-05-05

## [1.0.0-beta.2] - 2021-03-24
### Changed
- Update Elixir to 1.11.4 and Erlang/OTP to 23.2
- Do not authorize non-devices blindly in `auth_on_publish` and `auth_on_subscribe`.

## [1.0.0-beta.1] - 2021-02-16
### Changed
- Default data_queue_count to 128.

## [1.0.0-alpha.1] - 2020-06-19
### Added
- Send a periodic heartbeat for every connected device.
- Support SSL for RabbitMQ connections.
- Default max certificate chain length to 10.
- Reply with local and remote matches when a publish is requested.
- Allow configuring `max_offline_messages` and `persistent_client_expiration` with Docker env
  variables

## [0.11.4] - 2021-01-26
### Fixed
- Fix a bug where the plugin would remain unfunctional after suddenly disconnecting from RabbitMQ.

## [0.11.3] - 2020-09-24
### Fixed
- Fix bug that prevented property unset

## [0.11.2] - 2020-08-14
### Added
- Update Elixir to 1.8.2

## [0.11.1] - 2020-05-18
### Added
- Enhance docker build process

## [0.11.0] - 2020-04-13

## [0.11.0-rc.1] - 2020-03-26

## [0.11.0-rc.0] - 2020-02-26

## [0.11.0-beta.2] - 2020-01-24

## [0.11.0-beta.1] - 2019-12-26
### Added
- Add support to multiple queues with consistent hashing

## [0.10.2] - 2019-12-09

## [0.10.1] - 2019-10-02

## [0.10.0] - 2019-04-16

## [0.10.0-rc.1] - 2019-04-10
### Fixed
- Re-enable SSL listener, which broke Docker Compose.

## [0.10.0-rc.0] - 2019-04-03

## [0.10.0-beta.3] - 2018-12-19

## [0.10.0-beta.2] - 2018-10-19

## [0.10.0-beta.1] - 2018-08-27
### Added
- First Astarte release.
