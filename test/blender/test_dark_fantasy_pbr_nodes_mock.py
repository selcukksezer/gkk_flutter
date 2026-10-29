#!/usr/bin/env python3
"""
Standalone Mock Unit Tests for Dark Fantasy PBR Shader Node Graph Master
========================================================================
Runs in standard Python environments (e.g. pytest) without requiring Blender.
Mocks Blender's bpy data structures to test logic, socket routing, math setup,
and configuration builders.
"""

import os
import sys
import unittest
from unittest.mock import MagicMock

scripts_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "scripts", "blender"))
if scripts_dir not in sys.path:
    sys.path.insert(0, scripts_dir)


# Create a lightweight mock for bpy before importing dark_fantasy_pbr_nodes
class MockSocket:
    def __init__(self, name, socket_type='VALUE', enabled=True, is_output=False):
        self.name = name
        self.type = socket_type
        self.enabled = enabled
        self.is_output = is_output
        self.is_linked = False
        self.links = []
        self.default_value = 0.0

    def __repr__(self):
        return f"<MockSocket {self.name} ({self.type})>"


class MockLink:
    def __init__(self, from_node, from_socket, to_node, to_socket):
        self.from_node = from_node
        self.from_socket = from_socket
        self.to_node = to_node
        self.to_socket = to_socket
        self.is_valid = True


class MockNode:
    def __init__(self, bl_idname, name=None):
        self.bl_idname = bl_idname
        self.name = name or bl_idname
        self.label = self.name
        self.location = (0.0, 0.0)
        self.inputs = MockSocketCollection()
        self.outputs = MockSocketCollection()
        self.operation = 'ADD'
        self.use_clamp = False
        self.data_type = 'RGBA'
        self.blend_type = 'MIX'
        self.color_ramp = MagicMock()
        self.color_ramp.elements = [MagicMock(position=0.0, color=(0,0,0,1)), MagicMock(position=1.0, color=(1,1,1,1))]
        self.parent = None
        self._init_default_sockets()

    def _init_default_sockets(self):
        if self.bl_idname == 'ShaderNodeBsdfPrincipled':
            self.inputs._add(MockSocket('Base Color', 'RGBA'))
            self.inputs._add(MockSocket('Metallic', 'VALUE'))
            self.inputs._add(MockSocket('Roughness', 'VALUE'))
            self.inputs._add(MockSocket('Coat Weight', 'VALUE'))
            self.inputs._add(MockSocket('Coat Roughness', 'VALUE'))
            self.inputs._add(MockSocket('Normal', 'VECTOR'))
            self.inputs._add(MockSocket('Specular IOR Level', 'VALUE'))
            self.inputs._add(MockSocket('Emission Color', 'RGBA'))
            self.inputs._add(MockSocket('Emission Strength', 'VALUE'))
            self.outputs._add(MockSocket('BSDF', 'SHADER', is_output=True))
        elif self.bl_idname == 'ShaderNodeOutputMaterial':
            self.inputs._add(MockSocket('Surface', 'SHADER'))
        elif self.bl_idname == 'ShaderNodeTexCoord':
            self.outputs._add(MockSocket('UV', 'VECTOR', is_output=True))
            self.outputs._add(MockSocket('Normal', 'VECTOR', is_output=True))
        elif self.bl_idname == 'ShaderNodeValue':
            self.outputs._add(MockSocket('Value', 'VALUE', is_output=True))
        elif self.bl_idname == 'ShaderNodeMapping':
            self.inputs._add(MockSocket('Vector', 'VECTOR'))
            self.inputs._add(MockSocket('Scale', 'VECTOR'))
            self.outputs._add(MockSocket('Vector', 'VECTOR', is_output=True))
        elif self.bl_idname == 'ShaderNodeTexNoise':
            self.inputs._add(MockSocket('Vector', 'VECTOR'))
            self.inputs._add(MockSocket('Scale', 'VALUE'))
            self.inputs._add(MockSocket('Detail', 'VALUE'))
            self.inputs._add(MockSocket('Roughness', 'VALUE'))
            self.inputs._add(MockSocket('Distortion', 'VALUE'))
            self.outputs._add(MockSocket('Fac', 'VALUE', is_output=True))
            self.outputs._add(MockSocket('Color', 'RGBA', is_output=True))
        elif self.bl_idname == 'ShaderNodeTexVoronoi':
            self.inputs._add(MockSocket('Vector', 'VECTOR'))
            self.inputs._add(MockSocket('Scale', 'VALUE'))
            self.outputs._add(MockSocket('Distance', 'VALUE', is_output=True))
            self.outputs._add(MockSocket('Color', 'RGBA', is_output=True))
        elif self.bl_idname == 'ShaderNodeMath':
            self.inputs._add(MockSocket('Value', 'VALUE'))
            self.inputs._add(MockSocket('Value', 'VALUE'))
            self.outputs._add(MockSocket('Value', 'VALUE', is_output=True))
        elif self.bl_idname == 'ShaderNodeAmbientOcclusion':
            self.inputs._add(MockSocket('Distance', 'VALUE'))
            self.outputs._add(MockSocket('Color', 'RGBA', is_output=True))
            self.outputs._add(MockSocket('AO', 'VALUE', is_output=True))
        elif self.bl_idname == 'ShaderNodeNormalMap':
            self.inputs._add(MockSocket('Strength', 'VALUE'))
            self.inputs._add(MockSocket('Color', 'RGBA'))
            self.outputs._add(MockSocket('Normal', 'VECTOR', is_output=True))
        elif self.bl_idname == 'ShaderNodeLayerWeight':
            self.inputs._add(MockSocket('Blend', 'VALUE'))
            self.outputs._add(MockSocket('Fresnel', 'VALUE', is_output=True))
            self.outputs._add(MockSocket('Facing', 'VALUE', is_output=True))
        elif self.bl_idname == 'ShaderNodeValToRGB':
            self.inputs._add(MockSocket('Fac', 'VALUE'))
            self.outputs._add(MockSocket('Color', 'RGBA', is_output=True))
            self.outputs._add(MockSocket('Alpha', 'VALUE', is_output=True))
        elif self.bl_idname == 'ShaderNodeMix':
            # Modern 10-input ShaderNodeMix
            self.inputs._add(MockSocket('Factor', 'VALUE'))
            self.inputs._add(MockSocket('Factor', 'VECTOR', enabled=False))
            self.inputs._add(MockSocket('A', 'VALUE'))
            self.inputs._add(MockSocket('B', 'VALUE'))
            self.inputs._add(MockSocket('A', 'VECTOR', enabled=False))
            self.inputs._add(MockSocket('B', 'VECTOR', enabled=False))
            self.inputs._add(MockSocket('A', 'RGBA'))
            self.inputs._add(MockSocket('B', 'RGBA'))
            self.inputs._add(MockSocket('A', 'ROTATION', enabled=False))
            self.inputs._add(MockSocket('B', 'ROTATION', enabled=False))
            self.outputs._add(MockSocket('Result', 'VALUE'))
            self.outputs._add(MockSocket('Result', 'VECTOR', enabled=False))
            self.outputs._add(MockSocket('Result', 'RGBA'))
            self.outputs._add(MockSocket('Result', 'ROTATION', enabled=False))
        elif self.bl_idname in ('NodeGroupInput', 'NodeGroupOutput'):
            pass


class MockSocketCollection:
    def __init__(self):
        self._sockets = []

    def _add(self, socket):
        self._sockets.append(socket)

    def __iter__(self):
        return iter(self._sockets)

    def __getitem__(self, key):
        if isinstance(key, int):
            return self._sockets[key]
        for s in self._sockets:
            if s.name == key:
                return s
        raise KeyError(f"Socket '{key}' not found")

    def __len__(self):
        return len(self._sockets)

    def get(self, key, default=None):
        for s in self._sockets:
            if s.name == key:
                return s
        return default


class MockNodeTree:
    def __init__(self):
        self.nodes = MockNodeCollection()
        self.links = MockLinkCollection()
        self.interface = MockInterface()


class MockInterface:
    def new_socket(self, name, in_out='INPUT', socket_type='NodeSocketFloat'):
        sock = MockSocket(name, socket_type)
        return sock


class MockNodeCollection:
    def __init__(self):
        self._nodes = []

    def new(self, bl_idname):
        node = MockNode(bl_idname)
        self._nodes.append(node)
        return node

    def clear(self):
        self._nodes.clear()

    def get(self, name, default=None):
        for n in self._nodes:
            if n.name == name:
                return n
        return default

    def __getitem__(self, key):
        if isinstance(key, int):
            return self._nodes[key]
        for n in self._nodes:
            if n.name == key:
                return n
        raise KeyError(f"Node '{key}' not found")

    def __iter__(self):
        return iter(self._nodes)

    def __len__(self):
        return len(self._nodes)


class MockLinkCollection:
    def __init__(self):
        self._links = []

    def new(self, from_socket, to_socket):
        from_node = None
        to_node = None
        link = MockLink(from_node, from_socket, to_node, to_socket)
        to_socket.is_linked = True
        to_socket.links.append(link)
        self._links.append(link)
        return link

    def __iter__(self):
        return iter(self._links)

    def __len__(self):
        return len(self._links)


class MockMaterial:
    def __init__(self, name):
        self.name = name
        self.use_nodes = True
        self.node_tree = MockNodeTree()


class MockBpyData:
    def __init__(self):
        self.materials = MockMaterialDict()
        self.node_groups = MockMaterialDict()


class MockMaterialDict:
    def __init__(self):
        self._items = {}

    def get(self, name, default=None):
        return self._items.get(name, default)

    def new(self, name, type_hint=None):
        if type_hint == 'ShaderNodeTree':
            tree = MockNodeTree()
            tree.name = name
            self._items[name] = tree
            return tree
        mat = MockMaterial(name)
        self._items[name] = mat
        return mat

    def remove(self, item):
        for k, v in list(self._items.items()):
            if v == item:
                del self._items[k]

    def __iter__(self):
        return iter(self._items.values())


mock_bpy = MagicMock()
mock_bpy.data = MockBpyData()


class TestMockDarkFantasyPBR(unittest.TestCase):
    def setUp(self):
        import dark_fantasy_pbr_nodes
        dark_fantasy_pbr_nodes.bpy = mock_bpy
        dark_fantasy_pbr_nodes.HAS_BPY = True
        self.df = dark_fantasy_pbr_nodes

    def test_mock_builder_presets(self):
        m = self.df.create_magical_rune_greatsword("Mock_Sword")
        self.assertIsNotNone(m)
        bsdf = m.node_tree.nodes.get("Principled_BSDF")
        self.assertIsNotNone(bsdf)

        stone = self.df.create_rainy_dungeon_stone("Mock_Stone")
        self.assertIsNotNone(stone)

        armor = self.df.create_cursed_blood_armor("Mock_Armor")
        self.assertIsNotNone(armor)

        gold = self.df.create_ancient_catacomb_gold("Mock_Gold")
        self.assertIsNotNone(gold)


if __name__ == '__main__':
    unittest.main()
