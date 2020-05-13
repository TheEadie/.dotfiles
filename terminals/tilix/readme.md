# Installation
To setup Tilix with default colours etc

```
./setup.sh
```

# Extract / import Tilix config

```
dconf dump /com/gexperts/Tilix/ > tilix.dconf
dconf load /com/gexperts/Tilix/ < tilix.dconf
```
