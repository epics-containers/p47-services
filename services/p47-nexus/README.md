# Nexus Setup

Before deploying Nexus, please review and update the following in your `values.yaml` file:

1. If your blueapi is NOT configured with the NumTracker service:
1a. configure a staticDirectory for NeXus files to be written into
1b. optionally configure a `nameTemplate` (see the default `application.yaml` in the NeXus service)
2. Define the NeXus base class of each device. The "synchrotron" device is already provided. Entries should map an ophyd/ophyd-async device by name to [a NexusBaseClass](https://alfred.diamond.ac.uk/documentation/javadocs/GDA/master/org/eclipse/dawnsci/nexus/NexusBaseClass.html)
3. Optionally configure templating for the NeXus file in the `template` field using the [NeXus templating format](https://alfred.diamond.ac.uk/documentation/manuals/GDA_Developer_Guide/master/nexus_file_writing/nexus_template_engine.html?highlight=templating#template-format)
3. Confirm that RabbitMQ is reachable at `p47-rabbitmq-daq.diamond.ac.uk`.
4. Specify the User ID in the security context to allow writing Nexus files. Typically, this should be set to `p47-detector` UID and GID. 
    You can find these by running: `id p47-detector`
