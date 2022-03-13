This project is the work-in-progress for one of my 2022 objective: measure CO2 that can be attributed to our family.

== Design ==

The first approach is to leverage banking data. The main reason is that banking data likely contains a lot of information about lifestyle and can help estimate.
There are good banking aggregators that do some kind of classification. I intend to use this classification to estimate CO2 emission of main source of CO2 in my life.
Estimation will be very raw, this first iteration aims for breadth (covering as many source of emission) instead of depth (very precise estimation of each event in my life).

== How to use ==

This will likely be a work in progress, reading the code is likely required. For now it is not even a real ruby gem but a in progress ruby on rails app.

As of 2022-03-10, one need several environment variables:
- `BRIDGEAPI_CLIENT_ID`: a client id for https://bridgeapi.io
- `BRIDGEAPI_CLIENT_SECRET`: the client secret for https://bridgeapi.io
- `BRIDGEAPI_EXPECTED_SIGNATURE`: the signature from bridgeapi events (of the form `v1=78IET....IESR788EI`)

Then:
`cd co2estimator`
`bundle exec bin/rails server`
