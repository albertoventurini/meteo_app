This repository contains code for meteoapp: a cloud application that downloads weather forecasts from the GFS model and generates maps of Europe out of it.

I designed the app so that it can work in a distributed way on two distinct machines: (1) a web server, and (2) an AWS virtual machine on Amazon Elastic Cloud service. The reason for that is that generating weather maps is a CPU-intensive task, and I don't want to burden a web server with CPU-intensive tasks. Therefore, the generation of maps is delegated to an AWS virtual machine, which is switched on on-demand and controlled from the web server.

The whole application is a set of bash scripts that do the following:

- (on the webserver) switch on the EC2 virtual machine
- (on the EC2 machine) download the GFS forecast
- (on the EC2 machine) use NCL to generate the weather maps
- (on the EC2 machine) create a tar archive with the .png maps
- (on the webserver) download the tar archive, which will be copied in a web-visible folder, along with an index.html and a simple Javascript.

It needs the NCL suite (http://www.ncl.ucar.edu/) to be installed on the AWS virtual machine.
