FROM registry.cn-guangzhou.aliyuncs.com/szmengran/rockylinux:jdk17.0.12

MAINTAINER Joe <android_li@sina.cn>


RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai  /etc/localtime

RUN echo "root:szmengran.com" | chpasswd

RUN groupadd -g 1003 publish && useradd -g 1003 -u 1003 -s /bin/zsh publish \
  && sed -e 's/\/root\//\/home\/publish\//g' /root/.zshrc > /home/publish/.zshrc

COPY fonts/* /usr/share/fonts/

# 默认工作目录
ARG work_dir="/data/dubbo"

WORKDIR ${work_dir}

ADD arthas/arthas.tar.gz ${work_dir}/

RUN ln -s ${work_dir}/arthas-boot.jar /usr/local/bin/arthas-boot.jar \
  && echo -e '#!/bin/sh\nexec java -jar /usr/local/bin/arthas-boot.jar "$@"' > /usr/local/bin/arthas \
  && chmod +x /usr/local/bin/arthas

COPY bin/* ${work_dir}/shell/
RUN chmod +x shell/*

RUN chown -R publish:publish /data /home/publish

USER publish

CMD ["shell/springboot-start.sh"]

# 构建命令 docker build -t registry.cn-guangzhou.aliyuncs.com/szmengran/szmengran-docker-base:jdk17.0.12 .