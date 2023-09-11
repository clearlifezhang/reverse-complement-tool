

The goal of this task is to launch a tool on EC2 (or other ) to compute a DNA reverse complement using the Python [Flask](https://flask.palletsprojects.com/en/2.3.x/) based code in this repository.  The tasks required are:

1. Launch an HTTP website on port 8080 (no need to TLS) on an AWS EC2.

2. Host the website using [nginx](https://www.nginx.com)


3. Make one unique feature addition, aka, to make the result downloadable, to the code base with documentation.

# Running Locally
Before deploying to AWS EC2, it would be good to test it locally, especially if we're going to make any changes or add a feature.
## Create a Conda Environment
Since we have an environment.devenv.yml file, we can create a conda environment for our project.
```bash 
conda env create -f environment.devenv.yml
```
activate the conda env:
```bash
conda activate takehome
 ```
## Run App Locally
Run the Flask application locally to test.
```bash
python wsgi.py
```
Navigate to http://localhost:8080 in our web browser to see if the app works as expected.
# Deploy to AWS EC2
You can deploy our project using the setupth.sh script. But before this, we have to create an AWS account(which is different from the general Amazon account).
## create an aws account
navigate to aws.amazon.com, and follow the guide to create an account if we don't have one already. This will let we log into the aws management console as root user.
## generate SSH key (.pem file)
You will need an SSH key pair to connect to our EC2 instance.
From AWS management console, follow [Services] -> [Compute] -> [EC2]-> [EC2 Dashboard]
to "Key Pairs" under the "Network & Security" section. Click on "Create key pair". Provide a name and choose the format (typically PEM for Linux instances).Click on "Create". As soon as we click "Create," a .pem file should automatically be downloaded to our computer. Keep .pem file in a safe place, and change the permission of this private key:
```bash
chmod 400 YourKeyPair.pem
```
NB: the associated public key is actually stored in the EC2 instance itself. When we launch a new EC2 instance and associate it with a key pair, AWS pushes the public key to the instance. This allows we to use the corresponding private key (the .pem file we downloaded) to SSH into the instance.

## Launch an EC2 instance with Ubuntu 22.04
Go to the AWS EC2 console and launch a new instance. In the "Choose an Amazon Machine Image (AMI)" step, we can search for an AMI (ami-024e6efaf93d85776) to get the specific Ubuntu version.
### Security Groups and Ports
In the instance configuration, we will reach a step where we can configure our security group. Make sure we add rules to allow traffic on the ports we will use for our Flask application. Typically, this might be port 80 for HTTP and port 443 for HTTPS, but it could be different if we've set our Flask app to run on another port (like Flask's default 5000). Also, make sure to allow SSH (port 22) so we can connect to the instance.   

More importantly, since we are using nginx as a reverse proxy, we should add an inbound rule as below:  
- Click on the "Edit inbound rules"
- Add a Rule: Click "Add rule" and add a new rule with these details  
   Type: Custom TCP  
   Protocol: TCP  
   Port Range: 8080  
   Source: Anywhere(or `0.0.0.0/0`)
- Save: Click the "Save rules" button  

If we want to test local-run on the EC2 instance, we should add an inbound rule for 5000 (replace 5000 for 8080 above)

### launch EC2 instance
after the configuration, we can launch a free tier EC2 instance (micro-t2). When the instance has started, we can copy the public IPv4 DNS, such as `ec2-34-229-252-123.compute-1.amazonaws.com`. We will use this ip address for ssh access of this instance.  
The command to connect to the running EC2
```bash
ssh -i "my-key.pem" ubuntu@ec2-34-229-252-123.compute-1.amazonaws.com
```
### set up the env on the EC2
- install miniconda
```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
chmod +x Miniconda3-latest-Linux-x86_64.sh
./Miniconda3-latest-Linux-x86_64.sh
source ~/.bashrc
```

### move the code to EC2 instance  
- git clone from github
- scp from local machine

### deployment of the app
#### Run Flask app locally on EC2
- create conda env
```bash
conda env create -f environment.devenv.yml
conda activate takehome
```
- enable a swap file (micro-t2 has only 1G memory)
```bash
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```
- install flask
```bash
conda install -c conda-forge flask
```
- start Flask app
```bash
export FLASK_APP=wsgi.py
export FLASK_ENV=development  # This sets the environment to development mode which enables features like debugger and code reloader.
flask run --host=0.0.0.0 --port=5000
```
This command will run the Flask app using its built-in server and will bind it to all IP addresses of the EC2 instance (0.0.0.0) on port 5000
```
* Serving Flask app 'wsgi.py' (lazy loading)
 * Environment: development
 * Debug mode: on
WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:5000
 * Running on http://172.31.41.237:5000
Press CTRL+C to quit
 * Restarting with stat
 * Debugger is active!
 * Debugger PIN: 130-040-655
```
- access the app
```
http://ec2-34-229-252-123.compute-1.amazonaws.com:5000/
```
- stop the app  

Once we've tested the local run, we can stop the Flask development server by pressing CTRL + C in the terminal where it's running.

#### Run Flask app by Gunicorn, Nginx
In production, we use Gunicorn as the wsgi application server, and use Nginx as web server.  
- run setupth.sh to create a vitual env, and to configure and start Gunicorn, Nginx service.
```bash
sudo chmod +x setupth.sh
./setupth.sh
```
Now that Gunicorn is running, we should be able to access our application via the web server Nginx as we've set it up to proxy to Gunicorn.

- Once the script is complete, we should be able to access our Flask application by visiting http://ec2-34-229-252-123.compute-1.amazonaws.com:8080 in a web browser.
- check status for gunicorn and nginx
```bash
sudo systemctl status gunicorn
sudo systemctl status nginx
cat /var/log/nginx/error.log
cat /var/log/nginx/access.log
```
NB: Remember that paths in virtual environments are sensitive. If we ever move, rename, or recreate a virtual environment, tools installed within it might have their paths broken.