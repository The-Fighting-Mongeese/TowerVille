import Foundation
import UIKit



class PlayState : State {
    
    static var activeGame : PlayState!
    
    let mapSize : Int = 10  // size of 1 side of the map (length and width)
    var map : Map!
    let shader = ShaderProgram(vertexShader: "PerVertex.vert", fragmentShader: "PerVertex.frag")

    //let minion : Minion
    var towers : [Tower] = []
    var _gold : Int = 0
    var goldEarned : Int = 0
    var gold : Int {
        get { return _gold }
        set {
            // if earning gold
            if newValue > _gold { goldEarned += (newValue - _gold) }
            _gold = newValue
        }
    }
    
    private var _lives : Int = 10
    var lives : Int {
        get { return _lives }
        set {
            if newValue <= 0 { gameOver() }
            else { _lives = newValue }
        }
    }

    var waveController : WaveController!
    var minions : [Minion] = []
    var minionsLeft : Int = 0
    var farms   : [Farm] = []
    var selectedTile : Tile?
    
    var camera : Camera!
    
    // flags
    var isSelectingStructure = false;   // selected a tile w/ a structure
    var isPickingStructure = false;     // selected a tile w/o a structure
    var paused = false
    
    // Mark: - Debug variables
    var debugFarm : Farm?
    
    // Mark: - Performance measurement
    var updateDuration : Double = 0
    var drawDuration : Double = 0
    
    
    override init(replacing : Bool = true, viewController : ViewController) {
        super.init(replacing: replacing, viewController: viewController)
        PlayState.activeGame = self

        // preload all assets - may take awhile
        AssetLoader.Instance.PreloadAssets(shader: self.shader)

        camera = OrthoCamPrefab(viewableTiles: self.mapSize)
        Camera.ActiveCamera = camera
        
        map = Map(fromShader: self.shader, mapSize: self.mapSize)
        setupLights()
        
        restart()
    }
    
    func restart()
    {
        // clean up
        towers.removeAll()
        farms.removeAll()
        minions.removeAll()
        map.clearAllStructures()
        viewController.hideGameOverMenu()
        lives = 10
        gold = 0
        
        // initiailze
        waveController = WaveController(shader : shader)
        
        // update map
        map.setupPathFromWaypoints(waypoints: (WaveController.WAYPOINTS_LVL1))
        map.compress()
        
        // create some default structures 
        self.gold = Farm.COST + SlowTower.COST + Tower.COST
        goldEarned = 0
        createFarm(tile: map.Tiles[17][9])
        createSlowTower(tile: map.Tiles[7][6])
        createBasicTower(tile: map.Tiles[7][4])

        // start the game
        paused = false
    }
    
    func gameOver()
    {
        paused = true
        
        // check if we should prompt user to enter in hs
        var scores = viewController.LoadScores()
        for score in scores
        {
            if goldEarned > score
            {
                viewController.SaveScore(score: goldEarned)
                break
            }
        }
        
        viewController.showGameOverMenu(wavesCompleted: waveController.currentWave, goldEarned: goldEarned)
    }
    
    override func update(dt: TimeInterval) {
        
        if paused { return }
        
        let startTime = Date()
        
        // use reverse enumeration to iterate once
        for (i,tower) in towers.enumerated().reversed() {
            if tower.destroy { towers.remove(at: i) }
            else { tower.update(dt: dt) }
        }
        
        for (i,farm) in farms.enumerated().reversed() {
            if farm.destroy { farms.remove(at: i) }
            else { farm.update(dt: dt) }
        }
        
        waveController.update(dt: dt)
        
        for guy in minions {
            guy.update(dt: dt)
        }
        
        updateDuration = startTime.timeIntervalSinceNow
    }
    
    override func draw() {
        
        let startTime = Date()
        
        shader.prepareToDraw()
        
        map.draw()
        
        for t in towers{
            t.draw()
        }
        
        for f in farms {
            f.draw()
        }
        
        for guy in minions {
            guy.draw()
        }
        
        drawDuration = startTime.timeIntervalSinceNow
        
        // update ui
        updateUi()
        
        let s = String(format: "Update: %.2f Draw: %.2f", updateDuration * -1000, drawDuration * -1000)
        
        viewController.debug_updateUiDisplay(s)
    }
    
    
    func updateUi()
    {
        viewController.healthLabel.text = "\(self.lives)"
        viewController.goldLabel.text = "\(self.gold)"
        viewController.wavesLabel.text = "WAVE: \(waveController.currentWave)"
        viewController.enemiesLabel.text = "ENEMIES: \(self.minionsLeft)"
    }
    
    
    override func processInput(x: Float, z: Float, u: Float, v: Float) {
        NSLog("PlayState processInput \(x) \(z), \(u) \(v)")
        if (isPickingStructure)
        {
            // clicking out of build menu - deselect
            selectedTile = nil;
            viewController.showBuildMenu(isShown: false)
            isPickingStructure = false
        }
        else
        {
            // clicking on tile (no menus open) - select
            selectedTile = self.map.Tiles[Int(round(x))][Int(round(-z))]
            
            if selectedTile?.type == TileType.Grass
            {
                if let structure = selectedTile?.structure
                {
                    viewController.showStructureMenu(structure)
                    isSelectingStructure = true
                }
                else
                {
                    viewController.showBuildMenu(isShown: true)
                    isPickingStructure = true
                }
            }
        }
    }
    
    override func processUiInput(action: UIActionType) {
        
        switch action {
            
            // BUILD MENU
        
        case .BuildTowerBasic:
            if createBasicTower(tile: selectedTile!) { deselect() }
            break
        case .BuildTowerSlow:
            if createSlowTower(tile: selectedTile!) { deselect() }
            break
        case .BuildTowerExplosion:
            if createExplodeTower(tile: selectedTile!) { deselect() }
            break
        case .BuildTowerFragment:
            if createFragmentTower(tile: selectedTile!) { deselect() }
            break
        case .BuildTowerLaser:
            if createLaserTower(tile: selectedTile!) { deselect() }
            break
        case .BuildResourceFarm:
            if createFarm(tile: selectedTile!) { deselect() }
            break
        case .BuildResourceSawMill:
            if createSawMill(tile: selectedTile!) { deselect() }
            break
        case .BuildResourceMine:
            if createMine(tile: selectedTile!) { deselect() }
            break
            
            // STRUCTURE SELECTION MENU
        
        case .UpgradeStructure:
            let structure = selectedTile!.structure!
            if gold >= structure.upgradeCost
            {
                gold -= structure.upgradeCost
                structure.upgrade()
            }
            viewController.hideStructureMenu()
            break
        case .RepairStructure:
            let structure = selectedTile!.structure!
            if gold >= structure.getRepairCost()
            {
                gold -= structure.getRepairCost()
                structure.health = structure.maxHealth
            }
            viewController.hideStructureMenu()
            break
        case .SellStructure:
            let structure = selectedTile!.structure!
            gold += structure.getSellCost()
            
            selectedTile?.structure = nil
            if let i = towers.index(where: { $0 === structure }) {
                towers.remove(at: i)
            } else if let i = farms.index(where: { $0 === structure }) {
                farms.remove(at: i)
            }
            viewController.hideStructureMenu()
            break
            
            // GAME OVER
            
        case .Retry:
            restart()
            viewController.hideGameOverMenu()
            break
        case .HighscoreSelected:
            StateMachine.Instance.lastState()
            viewController.showHighscoreMenu(isShown: true)
            break
            
            // ETC.
        
        case .BackSelected:
            if (isPickingStructure || isSelectingStructure)
            {
                deselect()
            }
            else
            {
                NSLog("Back to intro")
                StateMachine.Instance.lastState()
            }
            break
        default:
            NSLog("This action hasn't been implemented yet!")
        }
    
    }
    
    override func pause() {
        // this is the same as exit
    }
    
    override func resume() {
        // this is the same as enter
    }
    
    override func enter() {
        viewController.showScreen(screenType: .GameScreen);
    }
    
    override func exit() {
        NSLog("Playstate Exit")
        viewController.hideScreen(screenType: .GameScreen);
        towers.removeAll()
        farms.removeAll()
        minions.removeAll()
        PlayState.activeGame = nil;
        Camera.ActiveCamera = nil;
    }
    
    private func deselect()
    {
        // deselect
        selectedTile = nil
        
        // hide all menus
        viewController.showBuildMenu(isShown: false)
        viewController.hideStructureMenu()
        
        // lower all flags
        isPickingStructure = false
        isSelectingStructure = false
    }
    
}

// MARK: - Game initialization
extension PlayState
{
    func setupLights()
    {
        let directionalLight = DirectionalLight()
        directionalLight.xDir = 1
        directionalLight.yDir = -1
        directionalLight.zDir = -1
        directionalLight.lightIntensity = 0.125
        directionalLight.lightColor = Color(1,1,1,1)
        
        let pointLightLeft = PointLight()
        pointLightLeft.x = 4.0
        pointLightLeft.y = 5.0
        pointLightLeft.z = -4.0
        pointLightLeft.lightIntensity = 1.0
        pointLightLeft.lightColor = Color(222/255,107/255,40/255,1)
        
        let pointLightRename = PointLight()
        pointLightRename.x = 14.0
        pointLightRename.y = 5.0
        pointLightRename.z = -14.0
        pointLightRename.lightIntensity = 1.0
        pointLightRename.lightColor = Color(67/255,134/255,150/255,1)
    }
}

// MARK: - Structure creation
extension PlayState
{
    func createFarm(tile : Tile) -> Bool {
        if (self.gold < Farm.COST) { return false }
        if (tile.structure != nil) { return false }
        if (tile.type != TileType.Grass) { return false }
        
        let newFarm = Farm(self, shader)
        newFarm.SetValue(x: tile.x, y: tile.z)
        tile.SetStructure(newFarm)
        farms.append(newFarm)
        self.gold -= Farm.COST
        
        return true
    }
    
    func createSawMill(tile : Tile) -> Bool {
        if (self.gold < SawMill.COST) { return false }
        if (tile.structure != nil) { return false }
        if (tile.type != TileType.Grass) { return false }
        
        let newFarm = SawMill(self, shader)
        newFarm.SetValue(x: tile.x, y: tile.z)
        tile.SetStructure(newFarm)
        farms.append(newFarm)
        self.gold -= SawMill.COST
        
        return true
    }
    
    func createMine(tile : Tile) -> Bool {
        if (self.gold < Mine.COST) { return false }
        if (tile.structure != nil) { return false }
        if (tile.type != TileType.Grass) { return false }
        
        let newFarm = Mine(self, shader)
        newFarm.SetValue(x: tile.x, y: tile.z)
        tile.SetStructure(newFarm)
        farms.append(newFarm)
        self.gold -= Farm.COST
        
        return true
    }
    
    func createBasicTower(tile : Tile) -> Bool {
        if (self.gold < Tower.COST) { return false }
        if (tile.structure != nil) { return false }
        if (tile.type != TileType.Grass) { return false }
        
        let newTower = Tower(0, 0, shader:shader, color: Color(0.5, 0.5, 0.5, 1)) // grey
        tile.SetStructure(newTower)
        towers.append(newTower)
        self.gold -= Tower.COST
        
        return true
    }
    
    func createSlowTower(tile : Tile) -> Bool {
        if (self.gold < SlowTower.COST) { return false }
        if (tile.structure != nil) { return false }
        if (tile.type != TileType.Grass) { return false }
        
        let newTower = SlowTower(0, 0, shader:shader, color: Color(0, 0, 1, 1)) // blue
        tile.SetStructure(newTower)
        towers.append(newTower)
        self.gold -= SlowTower.COST
        
        return true
    }
    
    func createExplodeTower(tile : Tile) -> Bool {
        if (self.gold < ExplodeTower.COST) { return false }
        if (tile.structure != nil) { return false }
        if (tile.type != TileType.Grass) { return false }
        
        let newTower = ExplodeTower(0, 0, shader:shader, color: Color(1, 0, 0, 1)) // red
        tile.SetStructure(newTower)
        towers.append(newTower)
        self.gold -= ExplodeTower.COST
        
        return true
    }
    
    func createFragmentTower(tile : Tile) -> Bool {
        if (self.gold < FragmentationTower.COST) { return false }
        if (tile.structure != nil) { return false }
        if (tile.type != TileType.Grass) { return false }
        
        let newTower = FragmentationTower(0, 0, shader:shader, color: Color(0, 0, 1, 1)) // green
        tile.SetStructure(newTower)
        towers.append(newTower)
        self.gold -= FragmentationTower.COST
        
        return true
    }
    
    func createLaserTower(tile : Tile) -> Bool {
        if (self.gold < LaserTower.COST) { return false }
        if (tile.structure != nil) { return false }
        if (tile.type != TileType.Grass) { return false }
        
        let newTower = LaserTower(0, 0, shader:shader, color: Color(1, 0, 0, 1)) // red
        tile.SetStructure(newTower)
        towers.append(newTower)
        self.gold -= LaserTower.COST
        
        return true
    }
    
}
