Build image:

```bash
$ docker build -t tinyproxy .
```

Start tinyproxy without auth:

```bash
$ docker run -it --rm --name tinyproxy -p 8888:8888 tinyproxy
```
