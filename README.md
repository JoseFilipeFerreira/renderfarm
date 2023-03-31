# :tractor: renderfarm

Distributed batch video encoding

## why

Almost all of my [home server](https://github.com/JoseFilipeFerreira/suitcase)'s storage is filled with video files.
If the files are converted to a more efficient codec they can sometimes be compressed over 8 times leading to a reduction in overall costs.
However, when I start to encode media, all of my self-hosted services grind to a halt due to the abysmal specs of the server.

The purpose of this program is to offload the computational load of encoding video to one, or more, computers while having minimal impact on the performance of my home server. Effectively turning my old laptops into a makeshift render farm.

## how it works
```
remote_convert REMOTE REMOTE_DIR
```

1. finds all `mkv` files inside REMOTE_DIR on the REMOTE machine
1. for each file copies it to the local machine
1. runs handbrake to compress it and convert it to `mp4`
1. if it was compressed, replace the old file on the REMOTE with the new file
1. if it failed to compress, it will store this information and not repeat the attempt in future runs

## requirements
- HandBraceCli
- `ssh` access to the REMOTE
- `rsync` access to the REMOTE

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
