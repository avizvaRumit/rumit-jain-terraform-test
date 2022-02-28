Here we have some terraform to build a simple VPC network, for now we have just one instance running the web server 
Nginx in its default configuration, serving up the default welcome page. To run this use the following command...
You are not required to run the `apply` command. running a `plan` to validate the terraform code is also ok.

    terraform init && terraform apply -var-file=terraform.tfvars

We want this to be extended. You're tasked with making the alterations detailed below,

1. The AMI that we have choose to use is not guarantee to be the latest, please adjust the code to filter only the lastest public Amazon Linux 2 for this exercise.

2. We are looking to improve the security and segregation of our network we've decided we would like private subnets that
are not addressable on the internet. Modify the VPC to meet this requirement, the private subnets should still have egress
internet connectivity.

3. The EC2 instance running Nginx went down over the weekend, we had an outage, it's been decided that we need a solution 
that is more resilient than just a single instance. Please implement a solution that you'd be confident would continue 
to run in the event one instance goes down.