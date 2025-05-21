FROM registry.cn-guangzhou.aliyuncs.com/szmengran/centos-jdk:17.0.2

MAINTAINER Joe <android_li@sina.cn>


RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai  /etc/localtime

RUN echo "root:szmengran.com" | chpasswd

RUN groupadd -g 1003 publish && useradd -g 1003 -u 1003 -s /bin/zsh publish \
  && sed -e 's/\/root\//\/home\/publish\//g' /root/.zshrc > /home/publish/.zshrc

COPY fonts/* /usr/share/fonts/

# 默认工作目录
ARG work_dir="/data/dubbo"

WORKDIR ${work_dir}

COPY arthas/unzip /bin/
ADD arthas/arthas-3.6.7.tar.gz ${work_dir}/

COPY bin/* ${work_dir}/shell/
RUN chmod +x shell/*

RUN chown -R publish:publish /data /home/publish

USER publish

CMD ["shell/springboot-start.sh"]
