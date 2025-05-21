FROM centos:7.9.2009
RUN yum install -y iproute iputils bind-utils net-tools nc telnet tcpdump lsof vim zsh git && rm -rf /var/cache/yum
RUN sh -c "$(cur -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" && echo 'JAVA_HOME=/usr/java/jdk-17.0.9' >> ~/.zshrc && echo 'export PATH=$JAVA_HOME/bin:$PATH' >> ~/.zshrc
RUN echo 'export LC_ALL=en_US.UTF-8' >> ~/.zshrc && echo 'export LANG=en_US.UTF-8' >> ~/.zshrc
# wget https://download.oracle.com/java/17/latest/jdk-17_linux-x64_bin.tar.gz
ADD ./jdk-17.0.9 /usr/java/
RUN ln -s /usr/java/jdk-17.0.9/bin/java /usr/bin/java
RUN ln -s /usr/java/jdk-17.0.9/bin/jstat /usr/bin/jstat
RUN ln -s /usr/java/jdk-17.0.9/bin/jmap /usr/bin/jmap
RUN ln -s /usr/java/jdk-17.0.9/bin/jinfo /usr/bin/jinfo
RUN ln -s /usr/java/jdk-17.0.9/bin/jstack /usr/bin/jstack
RUN ln -s /usr/java/jdk-17.0.9/bin/jps /usr/bin/jps
RUN ln -s /usr/java/jdk-17.0.9/bin/jstatd /usr/bin/jstatd
CMD ["/bin/bash"]

# 构建命令 docker build -t registry.cn-guangzhou.aliyuncs.com/szmengran/centos:jdk17.0.9 .