for IP in $(cat clients.txt);
do
    #Install packages
        ssh $SSH_ARGS -ostricthostkeychecking=no $SSH_USER@$IP 'sudo apt update'
        ssh $SSH_ARGS -ostricthostkeychecking=no $SSH_USER@$IP 'sudo apt install -y openjdk-17-jdk wget tmux ant'

        # Install TPCC.
        ssh $SSH_ARGS -ostricthostkeychecking=no $SSH_USER@$IP 'rm -rf ~/tpcc; rm -rf ~/tpcc.tar.gz'
#       scp $SCP_ARGS -ostricthostkeychecking=no tpcc.tar.gz $SSH_USER@$IP:~
        ssh $SSH_ARGS -ostricthostkeychecking=no $SSH_USER@$IP 'git clone https://github.com/ctring/yugabyte-tpcc.git'
        ssh $SSH_ARGS -ostricthostkeychecking=no $SSH_USER@$IP 'cd yugabyte-tpcc; ant bootstrap'
        ssh $SSH_ARGS -ostricthostkeychecking=no $SSH_USER@$IP 'cd yugabyte-tpcc; ant resolve'
        ssh $SSH_ARGS -ostricthostkeychecking=no $SSH_USER@$IP 'cd yugabyte-tpcc; ant build'

        # Upload new limits.conf.
        scp $SCP_ARGS -ostricthostkeychecking=no limits.conf $SSH_USER@$IP:~
        ssh $SSH_ARGS -ostricthostkeychecking=no $SSH_USER@$IP 'sudo cp ~/limits.conf /etc/security/limits.conf'

        # Confirm limits are set correctly.
        ssh $SSH_ARGS -ostricthostkeychecking=no $SSH_USER@$IP 'ulimit -a'
done