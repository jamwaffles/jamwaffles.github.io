---
layout: post
title:  "Testing a billion branches"
date:   2017-12-21 09:42:08
categories: docker,aws
image:
---

Maybe not a billion, but it's a few anyway. [At work](https://cambridge-intelligence.com/) we use a pretty typical branching strategy. Each feature, bug or spike gets its own branch, and life is mostly good. Unless you're a tester. For cost and maintenance reasons, we have a limited number of test environments. We can't/don't want to start up a new machine for every branch, which instead presents us with a problem: how can a developer provide a consistent test environment for every feature or fix that needs testing? I set out to find a scalable solution to increase quality and reduce the time-to-live of features, which I'll cover in this post.

As we already use AWS to host our production environments, it was an obvious choice to run this project in AWS. AWS provides a few ways to run Docker containers in the cloud with varying levels of abstraction. You can run them on "bare metal" EC2 instances, but I went with AWS Elastic Container Service (ECS) in this instance for its automatic management and scaling features. The automatic port binding and tight Elastic Load Balancer (ELB) integration is an important part of letting this system manage itself.

# Architecture overview

My experience of AWS has always been one of both confusion at why it's so complicated, and wonderment at how powerful it is. I still can't decide which of those this architecture leans towards. I'm sure there are simplifications to be made, but it's working well for what we need it to do. The tool has been dubbed "The Orchestrator" by the CamIntel devs, so that's what I'll call it.

# Scaling the cluster automatically

ECS relies on two things to calculate capacity: CPU and RAM. For internal-only traffic, CPU usage is inconsequential (less than 1%), so I focus on how much RAM each container will need as a baseline. ECS can use this allocation to figure out how many containers can be provisioned per machine, and whether there is capacity left to provision another. One thing ECS doesn't do (at the time of writing anyway) is autoscale the EC2 instances underpinning the cluster. This seems a bit weird to me, but it's an easy problem to solve with Cloudwatch alarms.

blablabla

If you do this, you'll want to tune the alarm points over time. Finding the sweet spot between having enough memory free to start new containers and having an overprovisioned cluster depends on the usage volume, as well as the size of your chosen EC2 instances.

# Saving time and money

Conclusion basically

Introducing The Orchestrator into our dev workflow has been a net improvement. Its primary purpose was to save our QA department time when testing new features or fixes, and I think it achieved that purpose pretty well. An additional positive side effect is for developers themselves, who can now show of cool new features or ask for feedback simply by sharing a link, doing away with potentially complex setup procedures.

Another swag feature is the use of AWS spot instances. Spot instances utilise spare EC2 compute capacity at a vastly reduced cost. The trade off though is that a machine could be terminated at any time. This isn't good for a manually deployed webapp, but it's actually fine for the orchestrator! If a machine is terminated, the underlying autoscaling group for the ECS cluster will automatically place another spot request to bring the cluster back to capacity. All the services will then be started on the new machine, and we carry on as before with minimal downtime. It's important to note there is _some_ downtime, so using this in production might not be the best idea, but for an internal services it's fine.
