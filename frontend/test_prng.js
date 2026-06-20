const _prng = (a) => {
    let t = a += 0x6D2B79F5;
    t = Math.imul(t ^ t >>> 15, t | 1);
    t ^= t + Math.imul(t ^ t >>> 7, t | 61);
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
};

for (let i = 0; i < 1000000; i++) {
    const v = _prng(i);
    if (v < 0 || v >= 1 || isNaN(v)) {
        console.log("BAD VALUE:", v, "for i =", i);
    }
}
console.log("Done");
