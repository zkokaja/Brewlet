<h1>
<img src="images/brewlet-color.svg" alt="BrewLet Icon" width="64px" />
Brewlet
</h1>

<img src="images/release-badge.svg" alt="Release Version 1.0"/>

The missing menulet for brew.sh.

This menulet makes it easier to work with [brew.sh]. For example, you need to
manually check if some of your packages can be updated. With Brewlet it's easy:
if everything is working swimmingly, then you'll see the normal shadow 
<img src="images/brewlet-black.svg" width="16px" /> 
icon. If updates are available to be installed, the icon will become colored,
<img src="images/brewlet-color.svg" width="16px" /> , to get your attention.
Once clicked, you'll be able to take upgrade your packages, among other options.
In addition, Brewlet will periodically check the status of packages in the
background, so you don't have to.

<img src="images/statusmenu-example.png" width="300px"/>


## On the horizon

I am currently working on adding more features, listed in order of priority
here:

- Add preferences window for time intervals
- Ability to handle casks as well
- Notifications for available updates
- Better timer handling (missed fires)
- Ability to install brew if not found
- Look for missing packages
- Temporarily disable timers
- What if upgrading requires interaction?


## Developer

To generate images of different sizes, use [Inkscape] on the command line:

```bash
$ len=64 # or use a for loop
$ inkscape --export-type="png" \
           --export-file brewlet-"$len".png \
           -w "$len" \
           brewlet.svg
```

## License & Acknowledgements

Because this app is closely tied to `brew.sh`, I used their icon as a template.
I also decided to adopt their choice of license: BSD 2-Clause "Simplified" License.

## Security

Brewlet needs to be able to access the `brew.sh` shell script to get information 
and take action on your behalf. And access to your Downloads folder to export
a list of packages.

[brew.sh]: https://brew.sh
[Inkscape]: https://inkscape.org

