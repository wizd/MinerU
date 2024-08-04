# 使用Ubuntu基础镜像
FROM ubuntu:latest

# 设置环境变量为非交互式，避免安装过程中的提示
ENV DEBIAN_FRONTEND=noninteractive

# 更新包列表并安装必要的包
RUN apt-get update && \
    apt-get install -y \
    software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y \
        python3.10 \
        python3.10-venv \
        python3.10-distutils \
        python3-pip \
        wget \
        git \
        libgl1 \
        libglib2.0-0 \
        openssh-server \
        locales \
        && rm -rf /var/lib/apt/lists/*

# 生成并设置locale
RUN sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# 设置环境变量
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# 设置Python 3.10为默认python3
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

# 创建MinerU的虚拟环境
RUN python3 -m venv /opt/mineru_venv

# 激活虚拟环境并安装必要的Python包
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip install --upgrade pip && \
    pip install magic-pdf[full-cpu] detectron2 --extra-index-url https://myhloli.github.io/wheels/"

    
# 创建用户 'mineru'
RUN useradd --create-home --shell /bin/bash mineru

# 复制配置文件模板并设置模型目录
COPY magic-pdf.template.json /home/mineru/magic-pdf.json
RUN sed -i 's|/tmp/models|/opt/models|g' /home/mineru/magic-pdf.json
RUN mkdir -p /opt/models

# 修改SSH配置
RUN sed -i 's/#Port 22/Port 5033/' /etc/ssh/sshd_config
RUN chmod 644 /etc/ssh/sshd_config

# 给予mineru用户必要的权限
RUN chown mineru:mineru /var/run
RUN chmod 755 /var/run

# 为mineru用户创建SSH主机密钥
RUN mkdir -p /home/mineru/.ssh/etc
RUN ssh-keygen -t rsa -f /home/mineru/.ssh/etc/ssh_host_rsa_key -N ""
RUN ssh-keygen -t ecdsa -f /home/mineru/.ssh/etc/ssh_host_ecdsa_key -N ""
RUN ssh-keygen -t ed25519 -f /home/mineru/.ssh/etc/ssh_host_ed25519_key -N ""

# 设置正确的权限
RUN chown -R mineru:mineru /home/mineru/.ssh
RUN chmod 700 /home/mineru/.ssh
RUN chmod 600 /home/mineru/.ssh/etc/*_key

# 为mineru用户设置SSH
RUN mkdir -p /home/mineru/.ssh
# 注意：您需要提供authorized_keys文件
COPY ./ssh/id_rsa.pub /home/mineru/.ssh/authorized_keys
RUN chmod 700 /home/mineru/.ssh && chmod 600 /home/mineru/.ssh/authorized_keys
RUN chown -R mineru:mineru /home/mineru/.ssh

# 创建输入和输出目录
RUN mkdir /home/mineru/input /home/mineru/output \
    && chown -R mineru:mineru /home/mineru/input /home/mineru/output

WORKDIR /home/mineru

# 创建并设置脚本
COPY process_pdf.sh /home/mineru/process_pdf.sh
RUN chmod +x /home/mineru/process_pdf.sh
RUN chown mineru:mineru /home/mineru/process_pdf.sh

# 暴露SSH端口
EXPOSE 5033

# 切换到mineru用户
USER mineru

# 启动SSH服务（以mineru用户身份）
CMD ["/usr/sbin/sshd", "-D", "-f", "/etc/ssh/sshd_config", "-h", "/home/mineru/.ssh/etc/ssh_host_rsa_key", "-h", "/home/mineru/.ssh/etc/ssh_host_ecdsa_key", "-h", "/home/mineru/.ssh/etc/ssh_host_ed25519_key"]