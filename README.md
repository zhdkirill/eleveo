# eleveo
This is an exercise project on managing an infrastructure as a code.

___
## Level 1. Docker
Let's say I have a web app. A simple counter app written in Python and Flask. How to distribute it?
Container image!

Okay, that's easy: write a [Dockerfile](app/Dockerfile), build it with `docker build` and that's it!

Let's publish it now: Github actions can build and publish for me and everyone in the world with a [workflow](.github/workflows/image-ci.yml). The resulting image is avaiable on Github container registry.

You can try running this image with:
```
docker run -d ghcr.io/zhdkirill/eleveo:main
```
___
## Level 2. Kubernetes
Now the application is ready for distribution, so I can run it on a kubernetes cluster!

The application is stateless by my design, so all I need is a Deployment resource to control my pods and a Service resource to provide network access.
I packed both resource manifests into a [single file](roles/app/files/manifests.yaml).

You can try applying those manifests on your kubernetes cluster with a single command:
```
kubectl apply -f roles/app/files/manifests.yaml
```
*Sorry for the long path, I'll need that later* :wink:
___
## Level 3. Ansible
What if I don't have a kubernetes cluster? Let's deploy it!

There is an amazing [k3s](https://k3s.io) project that allows creating a kubernetes cluster on a single node.
I'm using [ansible](https://www.ansible.com) to provision the node and apply my manifest on the cluster.

My entrypoint is a [playbook](playbook.yaml) with [roles](roles) defined for the node. The roles make the logic code modular and more readable. There are 3 roles configured:

- [upgrade](roles/upgrade/tasks/main.yml) - upgrades host packages
- [k3s](roles/k3s/tasks/main.yml) - installs k3s
- [app](roles/app/tasks/main.yml) - deploys the app on k3s

You can deploy it on a server with a single command:
```
ansible-playbook playbook.yaml
```
The app would be available publicly on server port 8080.

**Note**: the play expects Ubuntu/Debian Linux distro
___
## Level 4. Terraform
Okay, but where do I get a server? AWS!

[Terraform](https://www.terraform.io) allows ~~*changing planets*~~ creating and managing complex cloud infrastructure with code, but I only need an instance. I will also set up networking for the instance and generate an SSH key to access it (just in case).
With [cloud-init](cloud-init.yaml) I can run my ansible playbook during the instance initialization phase, so I'll get my application deployed on k3s installed on the instance right away!

My terraform code is in [aws.tf](aws.tf) file and the infrastructure it describes can be created with a few commands:
```
terraform init      # init the directory, fetch plugins
terraform plan      # review the changes
terraform apply     # apply configuration
```
**Note**: don't forget to provide your AWS access credentials!
```
export AWS_ACCESS_KEY_ID="MY_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="MY_SUPER_SECRET_ACCESS_KEY"
```
___
## Bonus level. CI/CD
How can I make sure that the code in this repository works? Even if I change it?
A deployment pipeline!

Github actions allow me to deploy a version of my code on AWS and verify it works.
[My pipeline](.github/workflows/deployment.yml) follows strict logic:

1. Initialize terraform module
2. Verify terraform code
3. Apply terraform code
4. Wait for my deployed application to respond
5. **Always** cleanup all the resources