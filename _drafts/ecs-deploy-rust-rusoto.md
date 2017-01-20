# Let's write an ECS deploy script in Rust

The [Rusoto docs]() explain how it handles AWS keys[, which is the same as the AWS CLI]. In my case I'm using environment variables exported in my `~/.zshrc` but Rusoto supports other key formats as well.

The easiest way to get set up with AWS keys is to install the AWS CLI, [run `aws configure`](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html) and specify your keys.

Intro: Assumes AWS credentials are set up. Basic idea of what we're doing; getting some JSON, modifying some keys, deploying to ECS

3 steps:

- Get ECS stuff
- Modify ECS stuff
- Deploy new version with modified ECS stuff

---

Further: Tag Github repo with libgit or whatever in Rust
