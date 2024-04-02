<p>It should be considered to spend ~1 minute in the beginning to setup your terminal. In the real exam the vast majority of questions will be done from the main terminal.
For few you might need to ssh into another machine. Just be aware that configurations to your shell will not be transferred in this case.</p>

### Minimal Setup

<p>Alias</p>
<p>The alias k for kubectl will already be configured together with autocompletion. In case not you can configure it using this link.</p>

<p>Vim</p>
<p>Settings are in ~/.vimrc. Type these down to make them:

    set tabstop=2
    set expandtab
    set shiftwidth=2

<p> The 'expandtab' makes sure to use spaces for tabs.</p>

<p>Optional Setup</p>
<p>Fast dry-run output</p>

`export do="--dry-run=client -o yaml"`

<p>This way you can just run 'k run pod1 --image=nginx $do'. Short for "dry output", but use whatever name you like.</p>

<p>Fast pod delete</p>

`export now="--force --grace-period 0"`

<p>This way you can run k delete pod1 $now and don't have to wait for ~30 seconds termination time.</p>

<p>Persist bash settings</p>

<p>You can store aliases and other setup in ~/.bashrc if you're planning on using different shells or tmux.</p>

<p>Alias Namespace</p>

<p>In addition you could define an alias like:</p>

`alias kn='kubectl config set-context --current --namespace '`

<p>Which allows you to define the default namespace of the current context. Then once you switch a context or namespace you can just run:</p>

`kn default`        # set default to default

`kn my-namespace`   # set default to my-namespace

<p>But only do this if you used it before and are comfortable doing so. Else you need to specify the namespace for every call, which is also fine:</p>

`k -n my-namespace get all`

`k -n my-namespace get pod`

...

 
<p>Be fast</p>

<p>Use the history command to reuse already entered commands or use even faster history search through Ctrl r .</p>

<p>If a command takes some time to execute, like sometimes kubectl delete pod x. </p>
<p>You can put a task in the background using Ctrl z and pull it back into foreground running command fg.</p>

<p>You can delete pods fast with:</p>

`k delete pod x --grace-period 0 --force`


`k delete pod x $now` # if export from above is configured

 
<p>Vim</p>

<p>Be great with vim.</p>

`toggle vim line numbers`

<p>When in vim you can press Esc and type :set number or :set nonumber followed by Enter to toggle line numbers.</p>
<p>This can be useful when finding syntax errors based on line - but can be bad when wanting to mark&copy by mouse.</p>
<p>You can also just jump to a line number with Esc :22 + Enter.</p>

`copy&paste`

<p>Get used to copy/paste/cut with vim:</p>

Mark lines: `Esc+V` (then arrow keys)

Copy marked lines: `y`

Cut marked lines: `d`

Past lines: `p` or `P`

<p>Indent multiple lines</p>

<p>To indent multiple lines press Esc and type ':set shiftwidth=2'. First mark multiple lines using Shift v and the up/down keys.</p>
<p>Then to indent the marked lines press > or <. You can then press . to repeat the action.</p>

 
<p>Split terminal screen</p>

<p>By default tmux is installed and can be used to split your one terminal into multiple.</p>
<p>But just do this if you know your shit, because scrolling is different and copy&pasting might be weird.</p>
https://www.hamvocke.com/blog/a-quick-and-easy-guide-to-tmux
