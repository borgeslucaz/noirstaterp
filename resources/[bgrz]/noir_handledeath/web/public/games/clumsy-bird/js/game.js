var game = {
    data: {
        score : 0,
        steps: 0,
        start: false,
        newHiScore: false,
        muted: true,
        flapQueued: false
    },

    resources: [
        {name: "bg", type:"image", src: "data/img/bg.png"},
        {name: "clumsy", type:"image", src: "data/img/clumsy.png"},
        {name: "pipe", type:"image", src: "data/img/pipe.png"},
        {name: "logo", type:"image", src: "data/img/logo.png"},
        {name: "ground", type:"image", src: "data/img/ground.png"},
        {name: "gameover", type:"image", src: "data/img/gameover.png"},
        {name: "gameoverbg", type:"image", src: "data/img/gameoverbg.png"},
        {name: "hit", type:"image", src: "data/img/hit.png"},
        {name: "getready", type:"image", src: "data/img/getready.png"},
        {name: "new", type:"image", src: "data/img/new.png"},
        {name: "share", type:"image", src: "data/img/share.png"},
        {name: "tweet", type:"image", src: "data/img/tweet.png"},
        {name: "theme", type: "audio", src: "data/bgm/"},
        {name: "hit", type: "audio", src: "data/sfx/"},
        {name: "lose", type: "audio", src: "data/sfx/"},
        {name: "wing", type: "audio", src: "data/sfx/"},
    ],

    queueFlap: function () {
        game.data.flapQueued = true;
    },

    "onload": function() {
        if (!me.video.init(900, 600, {
            wrapper: "screen",
            scale : "auto",
            scaleMethod: "stretch"
        })) {
            alert("Your browser does not support HTML5 canvas.");
            return;
        }

        // Loading ekranını atla (iframe embed)
        me.state.set(me.state.LOADING, new (me.ScreenObject.extend({
            onResetEvent: function () {},
            onDestroyEvent: function () {}
        }))());

        me.audio.init("mp3,ogg");
        me.audio.disable();
        me.audio.setVolume(0);

        me.loader.preload(game.resources, this.loaded.bind(this));
    },

    "loaded": function() {
        me.state.set(me.state.MENU, new game.TitleScreen());
        me.state.set(me.state.PLAY, new game.PlayScreen());
        me.state.set(me.state.GAME_OVER, new game.GameOverScreen());

        me.input.bindKey(me.input.KEY.SPACE, "fly", true);
        me.input.bindKey(me.input.KEY.M, "mute", true);
        me.input.bindPointer(me.input.pointer.LEFT, me.input.KEY.SPACE);

        // Parent NUI Space iletir (iframe focus kaybı)
        window.addEventListener("keydown", function (event) {
            if (event.code !== "Space" && event.key !== " ") return;
            event.preventDefault();
            if (event.repeat) return;
            game.queueFlap();
        }, true);

        window.addEventListener("message", function (event) {
            var data = event.data;
            if (!data || data.type !== "clumsy-key") return;
            if (data.code === "Space" || data.key === " ") {
                game.queueFlap();
            }
        });

        try {
            window.focus();
        } catch (e) {}

        me.pool.register("clumsy", game.BirdEntity);
        me.pool.register("pipe", game.PipeEntity, true);
        me.pool.register("hit", game.HitEntity, true);
        me.pool.register("ground", game.Ground, true);

        me.state.change(me.state.MENU);
    }
};
